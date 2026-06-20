import SwiftUI

/// 文件列表页（NavigationStack Root）
/// - 搜索栏
/// - 离线横幅
/// - 文件夹/文件目录树
/// - 同步触发
/// - 设置入口
struct FileListView: View {
    @Binding var hasConfiguredRepo: Bool
    @StateObject private var localizationManager = LocalizationManager.shared

    @State private var folders: [FolderNode] = []
    @State private var searchQuery = ""
    @State private var syncState: SyncState = .idle
    @State private var isOffline = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var noteIndex: [String: URL] = [:]
    @State private var isLoading = true
    @State private var repoName = ""
    @State private var cloneError: String? = nil
    @State private var expandedFolderID: String? = nil
    @State private var selectedTag: String? = nil
    @State private var selectedStatus: String? = nil
    @State private var showTagPopover = false
    @State private var showStatusPopover = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    // 离线横幅
                    if isOffline {
                        OfflineBanner(lastSyncTime: nil)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // 搜索栏
                    searchBar

                    // 状态和标签过滤器
                    if !isLoading && cloneError == nil && !folders.isEmpty {
                        filterSelectors
                    }

                    // 文件列表
                    if isLoading {
                        Spacer()
                        SyncLoader()
                        Spacer()
                    } else if let error = cloneError {
                        Spacer()
                        EmptyStateView(
                            icon: "⚠️",
                            title: "clone_failed".localized,
                            description: "clone_failed_desc".localized(arguments: error)
                        )
                        Button(action: triggerInitialClone) {
                            Text("retry_clone".localized)
                                .font(ClaudeTypography.bodyFont.weight(.semibold))
                                .foregroundStyle(ClaudeColors.background)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(ClaudeColors.text)
                                .cornerRadius(8)
                        }
                        Spacer()
                    } else if filteredFolders.isEmpty && !searchQuery.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "📭",
                            title: "no_matching_notes".localized,
                            description: "no_matching_notes_desc".localized
                        )
                        Spacer()
                    } else if folders.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "📂",
                            title: "repo_empty".localized,
                            description: "repo_empty_desc".localized
                        )
                        Spacer()
                    } else {
                        fileListContent
                    }
                }
                
                // 悬浮的标签下拉菜单
                if showTagPopover {
                    // 半透明背景遮罩，点击可收起菜单
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showTagPopover = false
                            }
                        }
                        .transition(.opacity)
                    
                    TagSelectPopoverView(
                        allTags: allTags,
                        tagCounts: tagCounts,
                        selectedTag: $selectedTag,
                        isPresented: $showTagPopover
                    )
                    .frame(height: 320)
                    .background(ClaudeColors.background)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ClaudeColors.border, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 106) // 搜索栏高度(38) + 搜索栏上下padding(20) + 过滤器高度(36) = 94，微调至 106 刚好在过滤器下方
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)),
                        removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading))
                    ))
                }

                // 悬浮的状态下拉菜单
                if showStatusPopover {
                    // 半透明背景遮罩，点击可收起菜单
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showStatusPopover = false
                            }
                        }
                        .transition(.opacity)
                    
                    StatusSelectPopoverView(
                        allStatuses: allStatuses,
                        statusCounts: statusCounts,
                        selectedStatus: $selectedStatus,
                        isPresented: $showStatusPopover
                    )
                    .frame(width: 220, height: CGFloat(min(allStatuses.count * 44 + 60, 300)))
                    .background(ClaudeColors.background)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ClaudeColors.border, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 106)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)),
                        removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading))
                    ))
                }
            }
            .background(ClaudeColors.background)
            .navigationDestination(for: FileItem.self) { file in
                NoteReaderView(
                    fileURL: file.url,
                    noteIndex: noteIndex
                )
            }
            .navigationTitle(repoName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(repoName)
                        .font(ClaudeTypography.navTitleFont)
                        .foregroundStyle(ClaudeColors.text)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        // 同步按钮
                        Button(action: performSync) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 16))
                                .foregroundStyle(syncState == .syncing ? ClaudeColors.link : ClaudeColors.textSecondary)
                                .rotationEffect(.degrees(syncState == .syncing ? 360 : 0))
                                .animation(syncState == .syncing ? .linear(duration: 1.5).repeatForever(autoreverses: false) : .default, value: syncState)
                        }
                        .disabled(syncState == .syncing)

                        // 设置按钮
                        NavigationLink(destination: SettingsView(
                            hasConfiguredRepo: $hasConfiguredRepo,
                            repoURL: GitSyncService.shared.repoURL,
                            branch: GitSyncService.shared.branch
                        )) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16))
                                .foregroundStyle(ClaudeColors.textSecondary)
                        }
                    }
                }
            }
            .refreshable {
                await performSyncAsync()
            }
            .overlay(alignment: .bottom) {
                ToastView(message: toastMessage, isPresented: $showToast)
            }
            .onAppear {
                loadFiles()
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(ClaudeColors.textMuted)

            TextField("search_notes_placeholder".localized, text: $searchQuery)
                .font(ClaudeTypography.bodyFont)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ClaudeColors.textMuted)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(ClaudeColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ClaudeColors.border, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Filter Selectors

    private var filterSelectors: some View {
        HStack(spacing: 12) {
            // 状态过滤器
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showStatusPopover.toggle()
                    showTagPopover = false // 互斥收起
                }
            }) {
                HStack(spacing: 4) {
                    Text(selectedStatus != nil ? "\(selectedStatus!) (\(statusCounts[selectedStatus!] ?? 0))" : "status".localized)
                        .font(ClaudeTypography.monoCaptionFont)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundStyle(selectedStatus != nil ? ClaudeColors.link : ClaudeColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selectedStatus != nil ? ClaudeColors.link.opacity(0.1) : ClaudeColors.tagBackground)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // 标签过滤器
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showTagPopover.toggle()
                    showStatusPopover = false // 互斥收起
                }
            }) {
                HStack(spacing: 4) {
                    Text(selectedTag != nil ? "#\(selectedTag!) (\(tagCounts[selectedTag!] ?? 0))" : "tag".localized)
                        .font(ClaudeTypography.monoCaptionFont)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundStyle(selectedTag != nil ? ClaudeColors.link : ClaudeColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selectedTag != nil ? ClaudeColors.link.opacity(0.1) : ClaudeColors.tagBackground)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Spacer()
            
            // 清除过滤器按钮
            if selectedTag != nil || selectedStatus != nil {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTag = nil
                        selectedStatus = nil
                    }
                }) {
                    Text("clear_filter".localized)
                        .font(ClaudeTypography.monoCaptionFont)
                        .foregroundStyle(ClaudeColors.textMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var tagCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for folder in folders {
            for file in folder.children {
                for tag in file.tags {
                    counts[tag, default: 0] += 1
                }
            }
        }
        return counts
    }

    private var statusCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for folder in folders {
            for file in folder.children {
                if let status = file.status {
                    counts[status, default: 0] += 1
                }
            }
        }
        return counts
    }

    private var allTags: [String] {
        tagCounts.sorted {
            if $0.value == $1.value {
                return $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
            }
            return $0.value > $1.value
        }.map { $0.key }
    }

    private var allStatuses: [String] {
        statusCounts.sorted {
            if $0.value == $1.value {
                return $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
            }
            return $0.value > $1.value
        }.map { $0.key }
    }

    // MARK: - File List

    private var fileListContent: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(filteredFolders) { folder in
                    folderSection(folder)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private func folderSection(_ folder: FolderNode) -> some View {
        let isExpanded = isFolderExpanded(folder)
        
        Section {
            if isExpanded {
                ForEach(filesInFolder(folder)) { file in
                    NavigationLink(value: file) {
                        fileRow(file)
                    }
                    .listRowBackground(ClaudeColors.background)
                    .listRowSeparator(.hidden)
                }
            }
        } header: {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if expandedFolderID == folder.id {
                        expandedFolderID = nil
                    } else {
                        expandedFolderID = folder.id
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ClaudeColors.textMuted)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12)

                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .font(.caption)
                        .foregroundStyle(ClaudeColors.textMuted)

                    Text(folder.name)
                        .font(ClaudeTypography.monoCaptionFont.weight(.semibold))
                        .foregroundStyle(ClaudeColors.textSecondary)
                        .tracking(0.2)
                        .textCase(.uppercase)

                    Spacer()

                    Text("\(filesInFolder(folder).count)")
                        .font(ClaudeTypography.codeCaptionFont)
                        .foregroundStyle(ClaudeColors.textMuted)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
        }
    }

    private func fileRow(_ file: FileItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 14))
                .foregroundStyle(ClaudeColors.textMuted)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(ClaudeTypography.bodyFont.weight(.medium))
                    .foregroundStyle(ClaudeColors.text)
                    .lineLimit(2)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if !file.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(file.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(ClaudeTypography.monoCaptionFont)
                                .foregroundStyle(ClaudeColors.tagText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ClaudeColors.tagBackground)
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, 16)
        .contentShape(Rectangle())
    }

    private func isFolderExpanded(_ folder: FolderNode) -> Bool {
        if !searchQuery.isEmpty || selectedTag != nil || selectedStatus != nil {
            return true // 搜索或筛选时默认全部展开
        }
        return expandedFolderID == folder.id
    }

    // MARK: - Filtering

    private var filteredFolders: [FolderNode] {
        var result = folders

        // 1. 搜索过滤（覆盖 filename/title/tags/aliases，由 SearchService 索引驱动）
        if !searchQuery.isEmpty {
            let matchedEntries = SearchService.shared.filter(query: searchQuery)
            let matchedURLs = Set(matchedEntries.map { $0.fileURL })
            result = result.compactMap { folder in
                let filtered = folder.children.filter { matchedURLs.contains($0.url) }
                guard !filtered.isEmpty else { return nil }
                return FolderNode(name: folder.name, children: filtered)
            }
        }

        // 2. 标签过滤
        if let tag = selectedTag {
            result = result.compactMap { folder in
                let filtered = folder.children.filter {
                    $0.tags.contains(tag)
                }
                guard !filtered.isEmpty else { return nil }
                return FolderNode(name: folder.name, children: filtered)
            }
        }

        // 3. 状态过滤
        if let status = selectedStatus {
            result = result.compactMap { folder in
                let filtered = folder.children.filter {
                    $0.status == status
                }
                guard !filtered.isEmpty else { return nil }
                return FolderNode(name: folder.name, children: filtered)
            }
        }

        return result
    }

    private func filesInFolder(_ folder: FolderNode) -> [FileItem] {
        folder.children.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Actions

    private func loadFiles() {
        repoName = GitSyncService.shared.repoDisplayName

        guard GitSyncService.shared.isLocalRepoExists else {
            triggerInitialClone()
            return
        }

        // 如果已经加载过数据，就不再展示全屏 Loading，避免闪烁和状态丢失
        if folders.isEmpty {
            isLoading = true
        }
        cloneError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let scanner = FileScannerService.shared
            let scannedFolders = scanner.scanDirectory()
            let index = scanner.buildNoteIndex()
            SearchService.shared.rebuildIndex()

            DispatchQueue.main.async {
                self.folders = scannedFolders
                self.noteIndex = index
                self.isLoading = false
            }
        }
    }

    private func triggerInitialClone() {
        isLoading = true
        cloneError = nil

        Task {
            do {
                try await GitSyncService.shared.clone(
                    repoURL: GitSyncService.shared.repoURL,
                    branch: GitSyncService.shared.branch
                )
                await MainActor.run {
                    loadFiles()
                }
            } catch {
                await MainActor.run {
                    cloneError = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func performSync() {
        // 校验同步前置条件
        do {
            try GitSyncService.shared.validateForSync()
        } catch {
            toastMessage = error.localizedDescription
            showToast = true
            return
        }

        syncState = .syncing

        Task {
            do {
                try await GitSyncService.shared.sync()
                await MainActor.run {
                    syncState = .success
                    toastMessage = "sync_completed".localized
                    showToast = true
                    loadFiles()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if syncState == .success {
                            syncState = .idle
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    syncState = .error(.unknown(error.localizedDescription))
                    toastMessage = "sync_failed".localized(arguments: error.localizedDescription)
                    showToast = true

                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        syncState = .idle
                    }
                }
            }
        }
    }

    private func performSyncAsync() async {
        do {
            try GitSyncService.shared.validateForSync()
        } catch {
            await MainActor.run {
                toastMessage = error.localizedDescription
                showToast = true
            }
            return
        }

        syncState = .syncing

        do {
            try await GitSyncService.shared.sync()
            await MainActor.run {
                syncState = .success
                toastMessage = "sync_completed".localized
                showToast = true
                loadFiles()
            }
        } catch {
            await MainActor.run {
                syncState = .error(.unknown(error.localizedDescription))
                toastMessage = "sync_failed".localized(arguments: error.localizedDescription)
                showToast = true
            }
        }

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await MainActor.run {
            if syncState == .success || syncState == .idle { syncState = .idle }
        }
    }
}

// Make FileItem Hashable for NavigationStack value-based navigation
extension FileItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    FileListView(hasConfiguredRepo: .constant(true))
}

/// 流式布局（Flow Layout）
/// 用于将子视图横向排列，超出宽度时自动换行
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let width = proposal.width ?? 0
        
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxLineHeight: CGFloat = 0
        
        for size in sizes {
            if currentX + size.width > width {
                // 换行
                currentX = 0
                currentY += maxLineHeight + spacing
                maxLineHeight = 0
            }
            
            currentX += size.width + spacing
            maxLineHeight = max(maxLineHeight, size.height)
        }
        
        height = currentY + maxLineHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let width = bounds.width
        
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var maxLineHeight: CGFloat = 0
        
        for index in subviews.indices {
            let size = sizes[index]
            
            if currentX + size.width > bounds.minX + width {
                // 换行
                currentX = bounds.minX
                currentY += maxLineHeight + spacing
                maxLineHeight = 0
            }
            
            subviews[index].place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )
            
            currentX += size.width + spacing
            maxLineHeight = max(maxLineHeight, size.height)
        }
    }
}

/// 标签选择浮层视图
struct TagSelectPopoverView: View {
    let allTags: [String]
    let tagCounts: [String: Int]
    @Binding var selectedTag: String?
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    
    var filteredTags: [String] {
        if searchText.isEmpty {
            return allTags
        } else {
            return allTags.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部标题栏
            HStack {
                Text("select_tag".localized)
                    .font(ClaudeTypography.navTitleFont)
                    .foregroundStyle(ClaudeColors.text)
                
                Spacer()
                
                if selectedTag != nil {
                    Button("clear".localized) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTag = nil
                        }
                        isPresented = false
                    }
                    .font(ClaudeTypography.monoCaptionFont)
                    .foregroundStyle(ClaudeColors.link)
                    .padding(.trailing, 8)
                }
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ClaudeColors.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(ClaudeColors.textMuted)
                
                TextField("search_tags_placeholder".localized, text: $searchText)
                    .font(ClaudeTypography.monoCaptionFont)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(ClaudeColors.textMuted)
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(ClaudeColors.tagBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            Divider()
                .background(ClaudeColors.border)
            
            // 标签流式布局列表
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if filteredTags.isEmpty {
                        HStack {
                            Spacer()
                            Text("no_matching_tags".localized)
                                .font(ClaudeTypography.captionFont)
                                .foregroundStyle(ClaudeColors.textMuted)
                                .padding(.vertical, 32)
                            Spacer()
                        }
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(filteredTags, id: \.self) { tag in
                                let isSelected = selectedTag == tag
                                let count = tagCounts[tag] ?? 0
                                
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if isSelected {
                                            selectedTag = nil
                                        } else {
                                            selectedTag = tag
                                        }
                                    }
                                    isPresented = false
                                }) {
                                    Text("#\(tag) (\(count))")
                                        .font(ClaudeTypography.monoCaptionFont)
                                        .foregroundStyle(isSelected ? ClaudeColors.link : ClaudeColors.textSecondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? ClaudeColors.link.opacity(0.1) : ClaudeColors.tagBackground)
                                        .cornerRadius(15)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 15)
                                                .stroke(isSelected ? ClaudeColors.link.opacity(0.3) : Color.clear, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(ClaudeColors.background)
    }
}

/// 状态选择浮层视图
struct StatusSelectPopoverView: View {
    let allStatuses: [String]
    let statusCounts: [String: Int]
    @Binding var selectedStatus: String?
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部标题栏
            HStack {
                Text("select_status".localized)
                    .font(ClaudeTypography.navTitleFont)
                    .foregroundStyle(ClaudeColors.text)
                
                Spacer()
                
                if selectedStatus != nil {
                    Button("clear".localized) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedStatus = nil
                        }
                        isPresented = false
                    }
                    .font(ClaudeTypography.monoCaptionFont)
                    .foregroundStyle(ClaudeColors.link)
                    .padding(.trailing, 8)
                }
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ClaudeColors.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .background(ClaudeColors.border)
            
            // 状态列表
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(allStatuses, id: \.self) { status in
                        let isSelected = selectedStatus == status
                        let count = statusCounts[status] ?? 0
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if isSelected {
                                    selectedStatus = nil
                                } else {
                                    selectedStatus = status
                                }
                            }
                            isPresented = false
                        }) {
                            HStack {
                                Text(status)
                                    .font(ClaudeTypography.monoCaptionFont)
                                    .foregroundStyle(isSelected ? ClaudeColors.link : ClaudeColors.text)
                                
                                Spacer()
                                
                                Text("(\(count))")
                                    .font(ClaudeTypography.codeCaptionFont)
                                    .foregroundStyle(isSelected ? ClaudeColors.link : ClaudeColors.textMuted)
                                
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(ClaudeColors.link)
                                        .padding(.leading, 4)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(isSelected ? ClaudeColors.link.opacity(0.08) : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
        }
        .background(ClaudeColors.background)
    }
}
