import SwiftUI
import UIKit
import NukeUI
import Nuke
import Yams

/// 字体大小枚举
enum ReaderFontSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .small: return "font_size_small".localized
        case .medium: return "font_size_medium".localized
        case .large: return "font_size_large".localized
        }
    }
    
    var bodyFontSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 16
        case .large: return 18
        }
    }
    
    var lineSpacing: CGFloat {
        switch self {
        case .small: return 4
        case .medium: return 6
        case .large: return 8
        }
    }
    
    var titleFontSize: CGFloat {
        switch self {
        case .small: return 24
        case .medium: return 28
        case .large: return 32
        }
    }
    
    var h1FontSize: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 24
        case .large: return 28
        }
    }
    
    var h2FontSize: CGFloat {
        switch self {
        case .small: return 18
        case .medium: return 20
        case .large: return 22
        }
    }
    
    var h3FontSize: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 18
        case .large: return 20
        }
    }
}

/// 笔记阅读页
/// - 衬线体标题
/// - Frontmatter 折叠卡片
/// - textual/MarkdownUI 渲染正文
/// - WikiLinks Push 跳转
struct NoteReaderView: View {
    let fileURL: URL
    let noteIndex: [String: URL] // [笔记名(小写): .md 文件 URL]
    @Binding var selectedFile: FileItem?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("readerFontSize") private var fontSizeRaw: String = ReaderFontSize.medium.rawValue
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var fontSize: ReaderFontSize {
        ReaderFontSize(rawValue: fontSizeRaw) ?? .medium
    }

    @State private var frontmatterData: [String: Any] = [:]
    @State private var markdownDocument: SwiftMarkdownDocument?
    @State private var markdownString: String = ""
    @State private var noteTitle: String = ""
    @State private var isFrontmatterExpanded = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var isLoading = true
    
    // 新增功能状态
    @State private var showSetPropertiesSheet = false
    @State private var shareItems: IdentifiableShareItems? = nil
    @State private var isExporting = false
    @State private var isSyncing = false
    @State private var syncProgressMessage = ""

    private func readerContentForExport(isLazy: Bool) -> some View {
        VStack(alignment: .leading, spacing: ClaudeTypography.readerContentSpacing) {
            // 标题
            titleView

            // Frontmatter 卡片
            if !frontmatterData.isEmpty {
                frontmatterCard
            }

            // 正文（使用 MarkdownUI 渲染）
            if let document = markdownDocument {
                MarkdownRenderer(document: document, noteIndex: noteIndex, isLazy: isLazy) { noteName in
                    if let targetURL = noteIndex[noteName.lowercased()] {
                        return targetURL
                    } else {
                        return nil
                    }
                }
            } else {
                Text(markdownString)
                    .font(.system(size: fontSize.bodyFontSize, design: .serif))
                    .lineSpacing(fontSize.lineSpacing)
                    .foregroundStyle(ClaudeColors.text)
            }
        }
        .padding(ClaudeTypography.readerHorizontalPadding)
        .padding(.top, 24)
        .padding(.bottom, 40)
        .background(ClaudeColors.background)
    }

    private var readerContent: some View {
        readerContentForExport(isLazy: true)
    }

    var body: some View {
        ScrollView {
            VStack {
                if isLoading {
                    skeletonView
                        .transition(.opacity)
                } else {
                    readerContent
                        .transition(.opacity)
                        .textSelection(.enabled) // 启用文本选择与拷贝
                }
            }
            .frame(maxWidth: horizontalSizeClass == .regular ? 720 : .infinity)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(ClaudeColors.background)
        .navigationTitle(noteTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(noteTitle)
                    .font(ClaudeTypography.navTitleFont)
                    .foregroundStyle(ClaudeColors.text)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // 字体大小
                    Menu {
                        Picker("font_size".localized, selection: $fontSizeRaw) {
                            ForEach(ReaderFontSize.allCases) { size in
                                Text(size.displayName).tag(size.rawValue)
                            }
                        }
                    } label: {
                        Image(systemName: "textformat.size")
                            .font(.system(size: 16))
                            .foregroundStyle(ClaudeColors.textSecondary)
                    }
                    
                    // 更多操作
                    Menu {
                        Button(action: { showSetPropertiesSheet = true }) {
                            Label("set_properties".localized, systemImage: "tag")
                        }
                        Button(action: copyFullText) {
                            Label("copy_source".localized, systemImage: "doc.on.doc")
                        }
                        /*
                        // 暂时隐藏：由于 SwiftUI 离屏渲染及 LazyVStack 懒加载机制，
                        // 导出长图和 PDF 功能在部分复杂 Markdown 笔记下仍不够稳定，待后续方案进一步优化。
                        Button(action: captureLongScreenshot) {
                            Label("导出为图片", systemImage: "photo")
                        }
                        Button(action: exportToPDF) {
                            Label("导出为 PDF", systemImage: "doc.plaintext")
                        }
                        */
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(ClaudeColors.textSecondary)
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            ToastView(message: toastMessage, isPresented: $showToast)
        }
        .overlay {
            if isExporting {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("generating".localized)
                            .font(ClaudeTypography.monoCaptionFont)
                            .foregroundStyle(.white)
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                }
            }
        }
        .overlay {
            if isSyncing {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text(syncProgressMessage)
                            .font(ClaudeTypography.monoCaptionFont)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .frame(maxWidth: 280)
                }
            }
        }
        .sheet(isPresented: $showSetPropertiesSheet) {
            SetPropertiesSheet(
                fileURL: fileURL,
                currentFrontmatter: frontmatterData,
                onSave: saveProperties
            )
        }
        .sheet(item: $shareItems) { share in
            ShareSheet(activityItems: share.items)
        }
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "app", url.host == "note" {
                let noteName = url.lastPathComponent
                if let targetURL = noteIndex[noteName.lowercased()] {
                    selectedFile = FileItem(name: targetURL.deletingPathExtension().lastPathComponent, url: targetURL, isDirectory: false)
                } else {
                    toastMessage = "note_not_found".localized(arguments: noteName)
                    showToast = true
                }
                return .handled
            }
            return .systemAction
        })
        .onAppear(perform: loadNote)
    }

    // MARK: - Title

    private var titleView: some View {
        Text(noteTitle)
            .font(.system(size: fontSize.titleFontSize, design: .serif).bold())
            .foregroundStyle(ClaudeColors.text)
            .padding(.bottom, 4)
    }

    // MARK: - Frontmatter Card

    @ViewBuilder
    private var frontmatterCard: some View {
        let tags = extractTags()
        let updated = extractUpdated()

        VStack(spacing: 0) {
            // Header（可点击展开/收起）
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isFrontmatterExpanded.toggle() } }) {
                HStack(spacing: 10) {
                    // 图标
                    ZStack {
                        RoundedRectangle(cornerRadius: isFrontmatterExpanded ? 5 : 6)
                            .fill(ClaudeColors.tagBackground)
                            .frame(
                                width: isFrontmatterExpanded ? 24 : 28,
                                height: isFrontmatterExpanded ? 24 : 28
                            )
                        Image(systemName: "info.circle")
                            .font(isFrontmatterExpanded ? .system(size: 11) : .caption)
                            .foregroundStyle(ClaudeColors.textMuted)
                    }

                    // 摘要信息
                    VStack(alignment: .leading, spacing: isFrontmatterExpanded ? 0 : 3) {
                        Text("metadata".localized)
                            .font(ClaudeTypography.monoCaptionFont)
                            .foregroundStyle(ClaudeColors.textMuted)
                            .tracking(0.6)

                        if !isFrontmatterExpanded {
                            Group {
                                if let tags = tags, let updated = updated {
                                    (Text("tags".localized + " ")
                                        .font(ClaudeTypography.monoCaptionFont)
                                        .foregroundStyle(ClaudeColors.textMuted)
                                    + Text(tags + "   ")
                                        .font(.system(.caption, design: .serif))
                                        .foregroundStyle(ClaudeColors.textSecondary)
                                    + Text("updated".localized + " ")
                                        .font(ClaudeTypography.monoCaptionFont)
                                        .foregroundStyle(ClaudeColors.textMuted)
                                    + Text(updated)
                                        .font(.system(.caption, design: .serif))
                                        .foregroundStyle(ClaudeColors.textSecondary))
                                } else if let tags = tags {
                                    (Text("tags".localized + " ")
                                        .font(ClaudeTypography.monoCaptionFont)
                                        .foregroundStyle(ClaudeColors.textMuted)
                                    + Text(tags)
                                        .font(.system(.caption, design: .serif))
                                        .foregroundStyle(ClaudeColors.textSecondary))
                                } else if let updated = updated {
                                    (Text("updated".localized + " ")
                                        .font(ClaudeTypography.monoCaptionFont)
                                        .foregroundStyle(ClaudeColors.textMuted)
                                    + Text(updated)
                                        .font(.system(.caption, design: .serif))
                                        .foregroundStyle(ClaudeColors.textSecondary))
                                }
                            }
                            .lineLimit(1)
                            .truncationMode(.tail)
                        }
                    }

                    Spacer()

                    // 展开/收起按钮
                    Image(systemName: isFrontmatterExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(ClaudeColors.textMuted)
                }
                .padding(ClaudeTypography.cardPadding)
            }
            .buttonStyle(.plain)

            // Expanded body
            if isFrontmatterExpanded {
                Divider()
                    .background(ClaudeColors.border)
                    .padding(.horizontal, 14)

                frontmatterKVList
                    .padding(ClaudeTypography.cardPadding)
            }
        }
        .claudeCard()
    }

    private var frontmatterKVList: some View {
        LazyVGrid(
            columns: [
                GridItem(.fixed(90), alignment: .trailing),
                GridItem(.flexible(), alignment: .leading)
            ],
            spacing: 8
        ) {
            ForEach(
                frontmatterData.sorted(by: { $0.key < $1.key }),
                id: \.key
            ) { key, value in
                Text(key)
                    .font(ClaudeTypography.monoCaptionFont)
                    .foregroundStyle(ClaudeColors.textMuted)

                Text(formatValue(value))
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(ClaudeColors.textSecondary)
                    .lineLimit(3)
            }
        }
    }

    // MARK: - Actions

    private func loadNote() {
        isLoading = true
        
        // 先在主线程设置标题（这样导航栏标题能立刻显示，体验极佳）
        noteTitle = fileURL.deletingPathExtension().lastPathComponent
        
        // 在后台线程进行文件读取和 Markdown 解析
        DispatchQueue.global(qos: .userInitiated).async {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.25)) {
                        isLoading = false
                    }
                }
                return
            }
            
            let result = MarkdownPipeline.process(rawText: content, fileURL: fileURL)
            
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.25)) {
                    if let result = result {
                        frontmatterData = result.frontmatter
                        if let title = result.frontmatter["title"] as? String {
                            noteTitle = title
                        }
                        markdownDocument = result.document
                    }
                    markdownString = content
                    isLoading = false
                }
            }
        }
    }

    private func copyFullText() {
        UIPasteboard.general.string = markdownString
        toastMessage = "copied_to_clipboard".localized
        showToast = true
    }
    
    private func captureLongScreenshot() {
        isExporting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let imageURL = generateLongScreenshot() {
                shareItems = IdentifiableShareItems(items: [imageURL])
            } else {
                toastMessage = "generate_image_failed".localized
                showToast = true
            }
            isExporting = false
        }
    }
    
    private func exportToPDF() {
        isExporting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let pdfURL = generatePDF() {
                shareItems = IdentifiableShareItems(items: [pdfURL])
            } else {
                toastMessage = "generate_pdf_failed".localized
                showToast = true
            }
            isExporting = false
        }
    }
    
    private func saveProperties(_ newFrontmatter: [String: Any]) {
        isLoading = true
        
        // 将 [String: Any] 转换为 JSON 兼容 of [String: Sendable] 字典，避免并发捕获警告
        // 在 Swift 中，String, Int, Double, Bool, Array, Dictionary 等基础 JSON 类型都是 Sendable 的
        var tempProperties: [String: Sendable] = [:]
        for (key, value) in newFrontmatter {
            if let sendableValue = value as? String {
                tempProperties[key] = sendableValue
            } else if let sendableValue = value as? [String] {
                tempProperties[key] = sendableValue
            } else if let sendableValue = value as? Int {
                tempProperties[key] = sendableValue
            } else if let sendableValue = value as? Double {
                tempProperties[key] = sendableValue
            } else if let sendableValue = value as? Bool {
                tempProperties[key] = sendableValue
            }
        }
        let sendableProperties = tempProperties // 声明为 let 常量，确保并发捕获安全
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let rawText = try? String(contentsOf: fileURL, encoding: .utf8) else {
                DispatchQueue.main.async {
                    isLoading = false
                    toastMessage = "read_file_failed".localized
                    showToast = true
                }
                return
            }
            
            let noteContent = FrontmatterSplitter.split(rawText)
            var frontmatter = [String: Any]()
            
            if let yaml = noteContent.frontmatterYAML, !yaml.isEmpty {
                frontmatter = (try? Yams.load(yaml: yaml) as? [String: Any]) ?? [:]
            }
            
            // Merge new properties
            for (key, value) in sendableProperties {
                frontmatter[key] = value
            }
            
            do {
                let newYAML = try Yams.dump(object: frontmatter)
                let newContent = "---\n\(newYAML)---\n\n\(noteContent.pureMarkdownBody)"
                try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
                
                DispatchQueue.main.async {
                    loadNote()
                    triggerAutoSync()
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    toastMessage = "save_properties_failed".localized(arguments: error.localizedDescription)
                    showToast = true
                }
            }
        }
    }

    private func triggerAutoSync() {
        isSyncing = true
        syncProgressMessage = "sync_committing".localized
        
        Task {
            do {
                try await GitSyncService.shared.commitAndSync(fileURL: fileURL) { progress in
                    Task { @MainActor in
                        syncProgressMessage = progress
                    }
                }
                Task { @MainActor in
                    isSyncing = false
                    toastMessage = "sync_success".localized
                    showToast = true
                }
            } catch {
                Task { @MainActor in
                    isSyncing = false
                    toastMessage = "sync_failed_detail".localized(arguments: error.localizedDescription)
                    showToast = true
                }
            }
        }
    }

    // MARK: - Skeleton View

    private var skeletonView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 标题骨架
            RoundedRectangle(cornerRadius: 4)
                .fill(ClaudeColors.border.opacity(0.5))
                .frame(width: 220, height: 28)
            
            // 元数据卡片骨架
            RoundedRectangle(cornerRadius: 8)
                .fill(ClaudeColors.border.opacity(0.3))
                .frame(height: 64)
            
            // 正文骨架
            VStack(alignment: .leading, spacing: 14) {
                ForEach(0..<6, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ClaudeColors.border.opacity(0.4))
                        .frame(width: index == 5 ? 160 : (index == 3 ? 280 : nil), height: 16)
                }
            }
        }
        .padding(ClaudeTypography.readerHorizontalPadding)
        .padding(.top, 24)
    }

    // MARK: - Helpers

    private func extractTags() -> String? {
        if let tags = frontmatterData["tags"] as? [String] {
            return tags.joined(separator: ", ")
        }
        if let tagString = frontmatterData["tags"] as? String {
            return tagString
        }
        return nil
    }

    private func extractUpdated() -> String? {
        return frontmatterData["updated"] as? String
            ?? frontmatterData["date"] as? String
    }

    private func formatValue(_ value: Any) -> String {
        if let array = value as? [Any] {
            return array.map { "\($0)" }.joined(separator: ", ")
        }
        return "\(value)"
    }
}

// MARK: - Identifiable URL

struct IdentifiableURL: Identifiable, Hashable {
    var id: String { url.absoluteString }
    let url: URL

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: IdentifiableURL, rhs: IdentifiableURL) -> Bool {
        lhs.url == rhs.url
    }
}

// MARK: - Markdown Renderer

/// 将 swift-markdown Document 渲染为 SwiftUI View（采用分段渲染 + 懒加载机制）
struct MarkdownRenderer: View {
    let document: SwiftMarkdownDocument
    let noteIndex: [String: URL]
    let isLazy: Bool
    let onWikiLink: (String) -> URL?

    init(document: SwiftMarkdownDocument, noteIndex: [String: URL], isLazy: Bool = true, onWikiLink: @escaping (String) -> URL?) {
        self.document = document
        self.noteIndex = noteIndex
        self.isLazy = isLazy
        self.onWikiLink = onWikiLink
    }

    var body: some View {
        if isLazy {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(Array(document.children.enumerated()), id: \.offset) { _, child in
                    BlockView(markup: child, noteIndex: noteIndex, onWikiLink: onWikiLink)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(document.children.enumerated()), id: \.offset) { _, child in
                    BlockView(markup: child, noteIndex: noteIndex, onWikiLink: onWikiLink)
                }
            }
        }
    }
}

// MARK: - Block View

struct BlockView: View {
    let markup: SwiftMarkdownMarkup
    let noteIndex: [String: URL]
    let onWikiLink: (String) -> URL?
    
    @AppStorage("readerFontSize") private var fontSizeRaw: String = ReaderFontSize.medium.rawValue
    var fontSize: ReaderFontSize { ReaderFontSize(rawValue: fontSizeRaw) ?? .medium }

    var body: some View {
        switch markup {
        case let heading as SwiftMarkdownHeading:
            HeadingView(heading: heading, noteIndex: noteIndex, onWikiLink: onWikiLink)
            
        case let paragraph as SwiftMarkdownParagraph:
            if let image = extractSingleImage(from: paragraph) {
                ImageView(image: image)
            } else {
                ParagraphView(paragraph: paragraph, noteIndex: noteIndex, onWikiLink: onWikiLink)
            }
            
        case let list as SwiftMarkdownUnorderedList:
            UnorderedListView(list: list, noteIndex: noteIndex, onWikiLink: onWikiLink)
            
        case let list as SwiftMarkdownOrderedList:
            OrderedListView(list: list, noteIndex: noteIndex, onWikiLink: onWikiLink)
            
        case let codeBlock as SwiftMarkdownCodeBlock:
            CodeBlockView(codeBlock: codeBlock)
            
        case let blockquote as SwiftMarkdownBlockQuote:
            BlockQuoteView(blockquote: blockquote, noteIndex: noteIndex, onWikiLink: onWikiLink)
            
        case let table as SwiftMarkdownTable:
            TableView(table: table)
            
        case is SwiftMarkdownThematicBreak:
            ThematicBreakView()
            
        default:
            Text(renderFallback(markup))
                .font(.system(size: fontSize.bodyFontSize, design: .serif))
                .lineSpacing(fontSize.lineSpacing)
                .foregroundStyle(ClaudeColors.text)
        }
    }

    private func extractSingleImage(from paragraph: SwiftMarkdownParagraph) -> SwiftMarkdownImage? {
        if paragraph.childCount == 1, let image = paragraph.child(at: 0) as? SwiftMarkdownImage {
            return image
        }
        return nil
    }

    private func renderFallback(_ markup: SwiftMarkdownMarkup) -> AttributedString {
        var attr = AttributedString()
        for child in markup.children {
            if let text = child as? SwiftMarkdownText {
                attr.append(AttributedString(text.string))
            }
        }
        return attr
    }
}

// MARK: - Subviews

struct HeadingView: View {
    let heading: SwiftMarkdownHeading
    let noteIndex: [String: URL]
    let onWikiLink: (String) -> URL?
    
    @AppStorage("readerFontSize") private var fontSizeRaw: String = ReaderFontSize.medium.rawValue
    var fontSize: ReaderFontSize { ReaderFontSize(rawValue: fontSizeRaw) ?? .medium }

    var body: some View {
        Text(renderInlineChildren(heading, noteIndex: noteIndex, onWikiLink: onWikiLink, fontSize: fontSize))
            .font(fontForLevel(heading.level))
            .foregroundStyle(ClaudeColors.text)
            .padding(.top, heading.level == 1 ? 16 : 8)
            .padding(.bottom, 4)
    }

    private func fontForLevel(_ level: Int) -> Font {
        switch level {
        case 1: return .system(size: fontSize.h1FontSize, design: .serif).bold()
        case 2: return .system(size: fontSize.h2FontSize, design: .serif).bold()
        default: return .system(size: fontSize.h3FontSize, design: .serif).bold()
        }
    }
}

struct ParagraphView: View {
    let paragraph: SwiftMarkdownParagraph
    let noteIndex: [String: URL]
    let onWikiLink: (String) -> URL?
    
    @AppStorage("readerFontSize") private var fontSizeRaw: String = ReaderFontSize.medium.rawValue
    var fontSize: ReaderFontSize { ReaderFontSize(rawValue: fontSizeRaw) ?? .medium }

    var body: some View {
        Text(renderInlineChildren(paragraph, noteIndex: noteIndex, onWikiLink: onWikiLink, fontSize: fontSize))
            .font(.system(size: fontSize.bodyFontSize, design: .serif))
            .lineSpacing(fontSize.lineSpacing)
            .foregroundStyle(ClaudeColors.text)
    }
}

struct UnorderedListView: View {
    let list: SwiftMarkdownUnorderedList
    let noteIndex: [String: URL]
    let onWikiLink: (String) -> URL?
    
    @AppStorage("readerFontSize") private var fontSizeRaw: String = ReaderFontSize.medium.rawValue
    var fontSize: ReaderFontSize { ReaderFontSize(rawValue: fontSizeRaw) ?? .medium }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(list.listItems.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .font(.system(size: fontSize.bodyFontSize, design: .serif))
                        .foregroundStyle(ClaudeColors.textSecondary)
                        .frame(width: 12)
                    
                    ListItemContentView(item: item, noteIndex: noteIndex, onWikiLink: onWikiLink, fontSize: fontSize)
                }
            }
        }
        .padding(.leading, 8)
    }
}

struct OrderedListView: View {
    let list: SwiftMarkdownOrderedList
    let noteIndex: [String: URL]
    let onWikiLink: (String) -> URL?
    
    @AppStorage("readerFontSize") private var fontSizeRaw: String = ReaderFontSize.medium.rawValue
    var fontSize: ReaderFontSize { ReaderFontSize(rawValue: fontSizeRaw) ?? .medium }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(list.listItems.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.system(size: fontSize.bodyFontSize, design: .serif))
                        .foregroundStyle(ClaudeColors.textSecondary)
                        .frame(width: 20, alignment: .leading)
                    
                    ListItemContentView(item: item, noteIndex: noteIndex, onWikiLink: onWikiLink, fontSize: fontSize)
                }
            }
        }
        .padding(.leading, 8)
    }
}

/// 列表项内容：支持 inline 文本 + 嵌套子列表递归渲染
struct ListItemContentView: View {
    let item: SwiftMarkdownListItem
    let noteIndex: [String: URL]
    let onWikiLink: (String) -> URL?
    let fontSize: ReaderFontSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(item.children.enumerated()), id: \.offset) { _, child in
                if let paragraph = child as? SwiftMarkdownParagraph {
                    Text(renderInlineChildren(paragraph, noteIndex: noteIndex, onWikiLink: onWikiLink, fontSize: fontSize))
                        .font(.system(size: fontSize.bodyFontSize, design: .serif))
                        .lineSpacing(fontSize.lineSpacing)
                        .foregroundStyle(ClaudeColors.text)
                } else if let nestedList = child as? SwiftMarkdownUnorderedList {
                    UnorderedListView(list: nestedList, noteIndex: noteIndex, onWikiLink: onWikiLink)
                } else if let nestedList = child as? SwiftMarkdownOrderedList {
                    OrderedListView(list: nestedList, noteIndex: noteIndex, onWikiLink: onWikiLink)
                }
            }
        }
    }
}

struct CodeBlockView: View {
    let codeBlock: SwiftMarkdownCodeBlock
    @Environment(\.colorScheme) private var colorScheme
    @State private var highlightedCode: AttributedString?

    private static let highlighter = HighlightrCodeHighlighter()

    private var normalizedLanguage: String {
        LanguageNormalizer.normalize(codeBlock.language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if codeBlock.language != nil {
                Text(normalizedLanguage)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(ClaudeColors.textMuted)
                    .textCase(.uppercase)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ClaudeColors.border.opacity(0.3))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                if let highlighted = highlightedCode {
                    Text(highlighted)
                        .font(.system(.caption, design: .monospaced))
                        .padding(12)
                } else {
                    Text(codeBlock.code)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(ClaudeColors.textSecondary)
                        .padding(12)
                }
            }
        }
        .background(ClaudeColors.tagBackground)
        .cornerRadius(8)
        .padding(.vertical, 4)
        .task(id: colorScheme) {
            let theme: CodeHighlightTheme = colorScheme == .dark ? .dark : .light
            highlightedCode = Self.highlighter.highlight(code: codeBlock.code, language: normalizedLanguage, theme: theme)
        }
    }
}

struct BlockQuoteView: View {
    let blockquote: SwiftMarkdownBlockQuote
    let noteIndex: [String: URL]
    let onWikiLink: (String) -> URL?

    @AppStorage("readerFontSize") private var fontSizeRaw: String = ReaderFontSize.medium.rawValue
    var fontSize: ReaderFontSize { ReaderFontSize(rawValue: fontSizeRaw) ?? .medium }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blockquote.children.enumerated()), id: \.offset) { _, child in
                BlockView(markup: child, noteIndex: noteIndex, onWikiLink: onWikiLink)
            }
        }
        .padding(.leading, 16)
        .padding(.vertical, 4)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(ClaudeColors.accent.opacity(0.4))
                .frame(width: 3)
        }
    }
}

struct TableView: View {
    let data: TableData

    @AppStorage("readerFontSize") private var fontSizeRaw: String = ReaderFontSize.medium.rawValue
    var fontSize: ReaderFontSize { ReaderFontSize(rawValue: fontSizeRaw) ?? .medium }

    init(table: SwiftMarkdownTable) {
        self.data = MarkdownBlockClassifier.extractTable(table)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(data.headers.enumerated()), id: \.offset) { _, header in
                    Text(header)
                        .font(.system(size: fontSize.bodyFontSize, weight: .semibold, design: .serif))
                        .foregroundStyle(ClaudeColors.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
            }
            .background(ClaudeColors.tagBackground)

            ForEach(Array(data.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                            .font(.system(size: fontSize.bodyFontSize, design: .serif))
                            .foregroundStyle(ClaudeColors.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                }
                .overlay(alignment: .top) {
                    Rectangle().fill(ClaudeColors.border).frame(height: 0.5)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ClaudeColors.border, lineWidth: 0.5)
        )
        .cornerRadius(8)
        .padding(.vertical, 4)
    }
}

struct ThematicBreakView: View {
    var body: some View {
        Rectangle()
            .fill(ClaudeColors.border)
            .frame(height: 1)
            .padding(.vertical, 8)
    }
}

struct ImageView: View {
    let image: SwiftMarkdownImage
    @State private var isFullScreenPresented = false

    var body: some View {
        if let source = image.source, let url = URL(string: source) {
            VStack(alignment: .center, spacing: 8) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
                            .onTapGesture {
                                isFullScreenPresented = true
                            }
                    } else if state.error != nil {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title2)
                                .foregroundStyle(ClaudeColors.textMuted)
                            Text("image_load_failed".localized)
                                .font(ClaudeTypography.monoCaptionFont)
                                .foregroundStyle(ClaudeColors.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .background(ClaudeColors.tagBackground)
                        .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ClaudeColors.border.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .overlay {
                                ProgressView()
                                    .tint(ClaudeColors.textMuted)
                            }
                    }
                }
                
                if let title = image.title, !title.isEmpty {
                    Text(title)
                        .font(ClaudeTypography.monoCaptionFont)
                        .foregroundStyle(ClaudeColors.textMuted)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .fullScreenCover(isPresented: $isFullScreenPresented) {
                FullScreenImageViewer(url: url, title: image.title, isPresented: $isFullScreenPresented)
            }
        }
    }
}

// MARK: - Inline Rendering Helpers

func renderInlineChildren(_ markup: SwiftMarkdownMarkup, noteIndex: [String: URL], onWikiLink: (String) -> URL?, fontSize: ReaderFontSize) -> AttributedString {
    var attr = AttributedString()
    for child in markup.children {
        attr.append(renderInline(child, noteIndex: noteIndex, onWikiLink: onWikiLink, fontSize: fontSize))
    }
    return attr
}

func renderInline(_ markup: SwiftMarkdownMarkup, noteIndex: [String: URL], onWikiLink: (String) -> URL?, fontSize: ReaderFontSize) -> AttributedString {
    var attr = AttributedString()

    switch markup {
    case let text as SwiftMarkdownText:
        attr = AttributedString(text.string)

    case let emphasis as SwiftMarkdownEmphasis:
        var content = renderInlineChildren(emphasis, noteIndex: noteIndex, onWikiLink: onWikiLink, fontSize: fontSize)
        content.font = .system(size: fontSize.bodyFontSize, design: .serif).italic()
        attr = content

    case let strong as SwiftMarkdownStrong:
        var content = renderInlineChildren(strong, noteIndex: noteIndex, onWikiLink: onWikiLink, fontSize: fontSize)
        content.font = .system(size: fontSize.bodyFontSize, design: .serif).bold()
        attr = content

    case let link as SwiftMarkdownLink:
        let destination = link.destination ?? ""
        var content = renderInlineChildren(link, noteIndex: noteIndex, onWikiLink: onWikiLink, fontSize: fontSize)
        if destination.hasPrefix("app://note/") {
            content.foregroundColor = UIColor(ClaudeColors.link)
            content.underlineStyle = .single
            content.link = URL(string: destination)
        } else {
            content.foregroundColor = UIColor(ClaudeColors.link)
            content.underlineStyle = .single
            content.link = URL(string: destination)
        }
        attr = content

    case let code as SwiftMarkdownInlineCode:
        var codeStr = AttributedString(code.code)
        codeStr.font = .system(size: fontSize.bodyFontSize - 2, design: .monospaced)
        codeStr.foregroundColor = UIColor(ClaudeColors.textSecondary)
        codeStr.backgroundColor = UIColor(ClaudeColors.tagBackground)
        attr = codeStr

    default:
        attr = renderInlineChildren(markup, noteIndex: noteIndex, onWikiLink: onWikiLink, fontSize: fontSize)
    }

    return attr
}

// MARK: - Full Screen Image Viewer

struct FullScreenImageViewer: View {
    let url: URL
    let title: String?
    @Binding var isPresented: Bool
    @State private var dragOffset: CGSize = .zero
    @State private var deviceOrientation: UIDeviceOrientation = .portrait
    
    @State private var uiImage: UIImage? = nil
    @State private var isLoading = true
    @State private var hasError = false

    var rotationAngle: Angle {
        switch deviceOrientation {
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        case .portraitUpsideDown:
            return .degrees(180)
        default:
            return .degrees(0)
        }
    }

    var isLandscape: Bool {
        deviceOrientation.isLandscape
    }

    var body: some View {
        ZStack {
            // Claude 风格背景色，支持拖拽渐变透明
            ClaudeColors.background
                .ignoresSafeArea()
                .opacity(Double(1.0 - min(max(dragOffset.height / 300.0, 0.0), 1.0)))

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(ClaudeColors.textSecondary)
                    Text("loading_image".localized)
                        .font(ClaudeTypography.monoCaptionFont)
                        .foregroundStyle(ClaudeColors.textSecondary)
                }
            } else if hasError {
                VStack(spacing: 16) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundStyle(ClaudeColors.textMuted)
                    Text("image_load_failed".localized)
                        .font(ClaudeTypography.titleFont)
                        .foregroundStyle(ClaudeColors.text)
                    Text("image_load_failed_desc".localized)
                        .font(ClaudeTypography.bodyFont)
                        .foregroundStyle(ClaudeColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
                .background(ClaudeColors.cardBackground)
                .cornerRadius(ClaudeTypography.cardCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: ClaudeTypography.cardCornerRadius)
                        .stroke(ClaudeColors.border, lineWidth: ClaudeTypography.cardBorderWidth)
                )
                .padding(20)
            } else if let uiImage = uiImage {
                GeometryReader { geometry in
                    ZoomableImageView(image: uiImage)
                        .frame(
                            width: isLandscape ? geometry.size.height : geometry.size.width,
                            height: isLandscape ? geometry.size.width : geometry.size.height
                        )
                        .rotationEffect(rotationAngle)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .offset(y: dragOffset.height)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if value.translation.height > 0 {
                                        dragOffset = value.translation
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.height > 120 {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            isPresented = false
                                        }
                                    } else {
                                        withAnimation(.spring()) {
                                            dragOffset = .zero
                                        }
                                    }
                                }
                        )
                }
                .ignoresSafeArea()
            }

            // 顶部关闭按钮 (Claude 风格)
            VStack {
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(ClaudeColors.text)
                            .frame(width: 36, height: 36)
                            .background(ClaudeColors.cardBackground)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(ClaudeColors.border, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                Spacer()
            }
            
            // 底部图片标题 (Claude 风格)
            if let title = title, !title.isEmpty, !isLoading, !hasError {
                VStack {
                    Spacer()
                    Text(title)
                        .font(ClaudeTypography.monoCaptionFont)
                        .foregroundStyle(ClaudeColors.textSecondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(ClaudeColors.cardBackground.opacity(0.9))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ClaudeColors.border, lineWidth: 1)
                        )
                        .padding(.bottom, 40)
                }
            }
        }
        .statusBarHidden(true)
        .onAppear {
            loadImage()
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            // Set initial orientation
            let current = UIDevice.current.orientation
            if current.isPortrait || current.isLandscape {
                deviceOrientation = current
            }
        }
        .onDisappear {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let orientation = UIDevice.current.orientation
            if orientation.isPortrait || orientation.isLandscape {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    deviceOrientation = orientation
                }
            }
        }
    }
    
    private func loadImage() {
        isLoading = true
        hasError = false
        Nuke.ImagePipeline.shared.loadImage(with: url) { result in
            isLoading = false
            switch result {
            case .success(let response):
                self.uiImage = response.image
            case .failure:
                self.hasError = true
            }
        }
    }
}

// MARK: - Zoomable Image View

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> CenteringScrollView {
        let scrollView = CenteringScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .clear

        let imageView = UIImageView()
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true

        scrollView.addSubview(imageView)
        scrollView.imageView = imageView
        context.coordinator.imageView = imageView

        // Add double tap gesture
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ uiView: CenteringScrollView, context: Context) {
        uiView.imageView?.image = image
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let zoomRect = zoomRectForScale(scrollView.maximumZoomScale, center: point, scrollView: scrollView)
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }

        private func zoomRectForScale(_ scale: CGFloat, center: CGPoint, scrollView: UIScrollView) -> CGRect {
            var zoomRect = CGRect.zero
            zoomRect.size.height = scrollView.frame.size.height / scale
            zoomRect.size.width  = scrollView.frame.size.width  / scale
            zoomRect.origin.x    = center.x - (zoomRect.size.width  / 2.0)
            zoomRect.origin.y    = center.y - (zoomRect.size.height / 2.0)
            return zoomRect
        }
    }
}

class CenteringScrollView: UIScrollView {
    var imageView: UIImageView?

    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard let imageView = imageView else { return }
        
        // If we are at minimum zoom, ensure imageView matches bounds
        if zoomScale == minimumZoomScale {
            imageView.frame = bounds
            contentSize = bounds.size
        }
        
        // Center the image view
        let offsetX = max((bounds.width - contentSize.width) * 0.5, 0.0)
        let offsetY = max((bounds.height - contentSize.height) * 0.5, 0.0)
        imageView.center = CGPoint(x: contentSize.width * 0.5 + offsetX, y: contentSize.height * 0.5 + offsetY)
    }
}

// MARK: - Share Sheet Helpers

struct IdentifiableShareItems: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Set Tags Sheet

struct SetPropertiesSheet: View {
    let fileURL: URL
    let currentFrontmatter: [String: Any]
    let onSave: ([String: Any]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var templateManager = PropertyTemplateManager.shared
    @State private var properties: [String: Any] = [:]
    @State private var newTag: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(templateManager.fields) { field in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(field.name.capitalized)
                                .font(ClaudeTypography.navTitleFont)
                                .foregroundStyle(ClaudeColors.textSecondary)
                            
                            VStack {
                                switch field.type {
                                case .date:
                                    DatePicker(
                                        "select_date".localized,
                                        selection: Binding<Date>(
                                            get: {
                                                if let dateStr = properties[field.name] as? String,
                                                   let date = dateFormatter.date(from: dateStr) {
                                                    return date
                                                }
                                                return Date()
                                            },
                                            set: { newDate in
                                                properties[field.name] = dateFormatter.string(from: newDate)
                                            }
                                        ),
                                        displayedComponents: .date
                                    )
                                    .font(ClaudeTypography.bodyFont)
                                    .foregroundStyle(ClaudeColors.text)
                                    
                                case .enum:
                                    if let options = field.options {
                                        let selectedValue = properties[field.name] as? String ?? ""
                                        Menu {
                                            ForEach(options, id: \.self) { option in
                                                Button(action: {
                                                    properties[field.name] = option
                                                }) {
                                                    HStack {
                                                        Text(option)
                                                        if option == selectedValue {
                                                            Image(systemName: "checkmark")
                                                        }
                                                    }
                                                }
                                            }
                                            if !selectedValue.isEmpty {
                                                Button(role: .destructive, action: {
                                                    properties[field.name] = ""
                                                }) {
                                                    Label("clear_selection".localized, systemImage: "trash")
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(selectedValue.isEmpty ? "please_select".localized : selectedValue)
                                                    .font(ClaudeTypography.bodyFont)
                                                    .foregroundStyle(selectedValue.isEmpty ? ClaudeColors.textSecondary : ClaudeColors.text)
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(ClaudeColors.accent)
                                            }
                                            .padding(.horizontal, 12)
                                            .frame(height: 38)
                                            .background(ClaudeColors.background)
                                            .cornerRadius(ClaudeTypography.cardCornerRadius)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: ClaudeTypography.cardCornerRadius)
                                                    .stroke(ClaudeColors.border, lineWidth: 1)
                                            )
                                        }
                                    }
                                    
                                case .tags:
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            TextField("input_new_tag".localized, text: $newTag)
                                                .font(ClaudeTypography.monoCaptionFont)
                                                .padding(.horizontal, 12)
                                                .frame(height: 38)
                                                .background(ClaudeColors.background)
                                                .cornerRadius(ClaudeTypography.cardCornerRadius)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: ClaudeTypography.cardCornerRadius)
                                                        .stroke(ClaudeColors.border, lineWidth: 1)
                                                )
                                                .autocorrectionDisabled()
                                                .textInputAutocapitalization(.never)
                                            
                                            Button(action: { addTag(to: field.name) }) {
                                                Text("add".localized)
                                                    .font(ClaudeTypography.monoCaptionFont.weight(.semibold))
                                                    .foregroundStyle(ClaudeColors.background)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 10)
                                                    .background(ClaudeColors.text)
                                                    .cornerRadius(ClaudeTypography.cardCornerRadius)
                                            }
                                            .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                        }
                                        
                                        let tags = extractTags(from: properties[field.name])
                                        if !tags.isEmpty {
                                            FlowLayout(spacing: 8) {
                                                ForEach(tags, id: \.self) { tag in
                                                    HStack(spacing: 4) {
                                                        Text("#\(tag)")
                                                            .font(ClaudeTypography.monoCaptionFont)
                                                            .foregroundStyle(ClaudeColors.textSecondary)
                                                        Button(action: { removeTag(tag, from: field.name) }) {
                                                            Image(systemName: "xmark.circle.fill")
                                                                .font(.system(size: 14))
                                                                .foregroundStyle(ClaudeColors.textMuted)
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(ClaudeColors.tagBackground)
                                                    .cornerRadius(15)
                                                }
                                            }
                                        }
                                    }
                                    
                                case .text:
                                    TextField("input_content".localized, text: Binding<String>(
                                        get: { properties[field.name] as? String ?? "" },
                                        set: { properties[field.name] = $0 }
                                    ))
                                    .font(ClaudeTypography.bodyFont)
                                    .padding(.horizontal, 12)
                                    .frame(height: 38)
                                    .background(ClaudeColors.background)
                                    .cornerRadius(ClaudeTypography.cardCornerRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ClaudeTypography.cardCornerRadius)
                                            .stroke(ClaudeColors.border, lineWidth: 1)
                                    )
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                }
                            }
                            .padding(14)
                            .background(ClaudeColors.cardBackground)
                            .cornerRadius(ClaudeTypography.cardCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: ClaudeTypography.cardCornerRadius)
                                    .stroke(ClaudeColors.border, lineWidth: ClaudeTypography.cardBorderWidth)
                            )
                        }
                        .padding(.horizontal, ClaudeTypography.cardPadding)
                    }
                }
                .padding(.vertical, 20)
            }
            .background(ClaudeColors.background)
            .navigationTitle("set_properties".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
                        .font(ClaudeTypography.bodyFont)
                        .foregroundStyle(ClaudeColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        onSave(properties)
                        dismiss()
                    }
                    .font(ClaudeTypography.bodyFont.weight(.semibold))
                    .foregroundStyle(ClaudeColors.text)
                }
            }
            .onAppear {
                properties = currentFrontmatter
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage.localeIdentifier)
        return formatter
    }
    
    private func extractTags(from value: Any?) -> [String] {
        if let tags = value as? [String] {
            return tags
        }
        if let tagString = value as? String {
            return tagString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        return []
    }
    
    private func addTag(to fieldName: String) {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var tags = extractTags(from: properties[fieldName])
        if !tags.contains(trimmed) {
            tags.append(trimmed)
            properties[fieldName] = tags
        }
        newTag = ""
    }
    
    private func removeTag(_ tag: String, from fieldName: String) {
        var tags = extractTags(from: properties[fieldName])
        tags.removeAll { $0 == tag }
        properties[fieldName] = tags
    }
}

// MARK: - Offscreen Rendering Extensions

extension NoteReaderView {

    // MARK: - NSAttributedString Rendering (bypasses SwiftUI render server)

    private func buildExportAttributedString() -> NSAttributedString {
        let result = NSMutableAttributedString()
        let hPad = ClaudeTypography.readerHorizontalPadding
        let contentWidth = UIScreen.main.bounds.width - hPad * 2
        _ = contentWidth // 消除未使用警告

        // 标题
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize.titleFontSize, weight: .bold),
            .foregroundColor: UIColor(ClaudeColors.text)
        ]
        result.append(NSAttributedString(string: noteTitle + "\n\n", attributes: titleAttrs))

        // 正文
        if let document = markdownDocument {
            for child in document.children {
                appendBlock(child, to: result)
            }
        } else {
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize.bodyFontSize),
                .foregroundColor: UIColor(ClaudeColors.text)
            ]
            result.append(NSAttributedString(string: markdownString, attributes: bodyAttrs))
        }
        return result
    }

    private func paragraphStyle(lineSpacing: CGFloat, indent: CGFloat = 0) -> NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = lineSpacing
        ps.paragraphSpacing = lineSpacing
        ps.firstLineHeadIndent = indent
        ps.headIndent = indent
        return ps
    }

    private func bodyFont() -> UIFont {
        UIFont.systemFont(ofSize: fontSize.bodyFontSize)
    }

    private func codeFont() -> UIFont {
        UIFont(name: "Menlo", size: fontSize.bodyFontSize - 2)
            ?? UIFont.monospacedSystemFont(ofSize: fontSize.bodyFontSize - 2, weight: .regular)
    }

    private func headingFont(level: Int) -> UIFont {
        let size: CGFloat
        switch level {
        case 1: size = fontSize.h1FontSize
        case 2: size = fontSize.h2FontSize
        default: size = fontSize.h3FontSize
        }
        return UIFont.systemFont(ofSize: size, weight: .bold)
    }

    private func bodyAttrs() -> [NSAttributedString.Key: Any] {
        [
            .font: bodyFont(),
            .foregroundColor: UIColor(ClaudeColors.text),
            .paragraphStyle: paragraphStyle(lineSpacing: fontSize.lineSpacing)
        ]
    }

    private func appendInline(_ markup: SwiftMarkdownMarkup, to result: NSMutableAttributedString, baseAttrs: [NSAttributedString.Key: Any]) {
        switch markup {
        case let text as SwiftMarkdownText:
            result.append(NSAttributedString(string: text.string, attributes: baseAttrs))
        case let code as SwiftMarkdownInlineCode:
            var attrs = baseAttrs
            attrs[.font] = codeFont()
            attrs[.backgroundColor] = UIColor(ClaudeColors.tagBackground)
            result.append(NSAttributedString(string: code.code, attributes: attrs))
        case let emphasis as SwiftMarkdownEmphasis:
            for child in emphasis.children {
                var attrs = baseAttrs
                if let f = attrs[.font] as? UIFont {
                    attrs[.font] = UIFont(descriptor: f.fontDescriptor.withSymbolicTraits(.traitItalic) ?? f.fontDescriptor, size: f.pointSize)
                }
                appendInline(child, to: result, baseAttrs: attrs)
            }
        case let strong as SwiftMarkdownStrong:
            for child in strong.children {
                var attrs = baseAttrs
                if let f = attrs[.font] as? UIFont {
                    attrs[.font] = UIFont(descriptor: f.fontDescriptor.withSymbolicTraits(.traitBold) ?? f.fontDescriptor, size: f.pointSize)
                }
                appendInline(child, to: result, baseAttrs: attrs)
            }
        case let link as SwiftMarkdownLink:
            var attrs = baseAttrs
            attrs[.foregroundColor] = UIColor.systemBlue
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            for child in link.children {
                appendInline(child, to: result, baseAttrs: attrs)
            }
        default:
            let text = markup.format()
            if !text.isEmpty {
                result.append(NSAttributedString(string: text, attributes: baseAttrs))
            }
        }
    }

    private func appendInlineChildren(_ markup: SwiftMarkdownMarkup, to result: NSMutableAttributedString, baseAttrs: [NSAttributedString.Key: Any]) {
        for child in markup.children {
            appendInline(child, to: result, baseAttrs: baseAttrs)
        }
    }

    private func appendBlock(_ markup: SwiftMarkdownMarkup, to result: NSMutableAttributedString) {
        switch markup {
        case let heading as SwiftMarkdownHeading:
            let attrs: [NSAttributedString.Key: Any] = [
                .font: headingFont(level: heading.level),
                .foregroundColor: UIColor(ClaudeColors.text),
                .paragraphStyle: paragraphStyle(lineSpacing: fontSize.lineSpacing)
            ]
            appendInlineChildren(heading, to: result, baseAttrs: attrs)
            result.append(NSAttributedString(string: "\n"))

        case let paragraph as SwiftMarkdownParagraph:
            appendInlineChildren(paragraph, to: result, baseAttrs: bodyAttrs())
            result.append(NSAttributedString(string: "\n"))

        case let codeBlock as SwiftMarkdownCodeBlock:
            let indent: CGFloat = 12
            var attrs: [NSAttributedString.Key: Any] = [
                .font: codeFont(),
                .foregroundColor: UIColor(ClaudeColors.text),
                .paragraphStyle: paragraphStyle(lineSpacing: 4, indent: indent)
            ]
            if let lang = codeBlock.language, !lang.isEmpty {
                attrs[.font] = UIFont.systemFont(ofSize: fontSize.bodyFontSize - 4, weight: .semibold)
                result.append(NSAttributedString(string: lang.uppercased() + "\n", attributes: attrs))
                attrs[.font] = codeFont()
            }
            result.append(NSAttributedString(string: codeBlock.code, attributes: attrs))
            if !codeBlock.code.hasSuffix("\n") {
                result.append(NSAttributedString(string: "\n"))
            }

        case let list as SwiftMarkdownUnorderedList:
            for item in list.listItems {
                let attrs = bodyAttrs()
                var listAttrs = attrs
                listAttrs[.paragraphStyle] = paragraphStyle(lineSpacing: fontSize.lineSpacing, indent: 20)
                result.append(NSAttributedString(string: "•  ", attributes: listAttrs))
                appendInlineChildren(item, to: result, baseAttrs: listAttrs)
                result.append(NSAttributedString(string: "\n"))
            }

        case let list as SwiftMarkdownOrderedList:
            for (i, item) in list.listItems.enumerated() {
                let attrs = bodyAttrs()
                var listAttrs = attrs
                listAttrs[.paragraphStyle] = paragraphStyle(lineSpacing: fontSize.lineSpacing, indent: 20)
                result.append(NSAttributedString(string: "\(list.startIndex + UInt(i)).  ", attributes: listAttrs))
                appendInlineChildren(item, to: result, baseAttrs: listAttrs)
                result.append(NSAttributedString(string: "\n"))
            }

        case is SwiftMarkdownEmphasis:
            let attrs = bodyAttrs()
            var italicAttrs = attrs
            italicAttrs[.font] = UIFont.italicSystemFont(ofSize: fontSize.bodyFontSize)
            appendInlineChildren(markup, to: result, baseAttrs: italicAttrs)
            result.append(NSAttributedString(string: "\n"))

        default:
            let text = markup.format()
            if !text.isEmpty {
                result.append(NSAttributedString(string: text, attributes: bodyAttrs()))
                result.append(NSAttributedString(string: "\n"))
            }
        }
    }

    // MARK: - Screenshot & PDF

    @MainActor
    private func generateLongScreenshot() -> URL? {
        let width = UIScreen.main.bounds.width
        let renderView = readerContentForExport(isLazy: false)
            .frame(width: width)
        
        let renderer = ImageRenderer(content: renderView)
        // 限制最大缩放比例为 2.0，防止超长笔记导致内存溢出
        renderer.scale = min(UIScreen.main.scale, 2.0)
        
        guard let image = renderer.uiImage else { return nil }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(noteTitle)
            .appendingPathExtension("png")
            
        // 确保目录存在并清理旧文件
        try? FileManager.default.createDirectory(at: tempURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        guard let data = image.pngData() else { return nil }
        try? data.write(to: tempURL)
        
        return FileManager.default.fileExists(atPath: tempURL.path) ? tempURL : nil
    }

    @MainActor
    private func generatePDF() -> URL? {
        let width: CGFloat = 8.27 * 72 // A4 width at 72 DPI (approx 595 points)
        let pageHeight: CGFloat = 11.69 * 72 // A4 height at 72 DPI (approx 842 points)
        
        let renderView = readerContentForExport(isLazy: false)
            .frame(width: width)
        
        let renderer = ImageRenderer(content: renderView)
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(noteTitle)
            .appendingPathExtension("pdf")
            
        // Ensure the directory exists and clean up old file
        try? FileManager.default.createDirectory(at: tempURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        renderer.render { size, context in
            var box = CGRect(x: 0, y: 0, width: width, height: pageHeight)
            
            guard let pdf = CGContext(tempURL as CFURL, mediaBox: &box, nil) else {
                return
            }
            
            let totalHeight = size.height
            let pageCount = Int(ceil(totalHeight / pageHeight))
            
            for page in 0..<pageCount {
                pdf.beginPDFPage(nil)
                
                pdf.saveGState()
                // 在 PDF 坐标系中（y 轴向上），为了绘制 SwiftUI 视图的下半部分，
                // 我们需要将绘制原点向上平移（正 y 方向），从而使下半部分内容对齐到当前页面。
                pdf.translateBy(x: 0, y: CGFloat(page) * pageHeight)
                context(pdf)
                pdf.restoreGState()
                
                pdf.endPDFPage()
            }
            
            pdf.closePDF()
        }
        
        return FileManager.default.fileExists(atPath: tempURL.path) ? tempURL : nil
    }
}

#Preview {
    NavigationStack {
        NoteReaderView(
            fileURL: URL(fileURLWithPath: "/tmp/test.md"),
            noteIndex: [:],
            selectedFile: .constant(nil)
        )
    }
}
