import Foundation
import Markdown

/// Obsidian 特有语法的 AST 改写器
/// 实现两件事：
/// 1. 相对路径图片 → file:// 沙盒绝对路径
/// 2. [[note]] / [[note|alias]] WikiLinks → app://note/ scheme Link 节点
public final class ObsidianElementRewriter: MarkupRewriter {

    /// 当前 .md 文件所在的沙盒目录 URL
    private let currentFileDirectory: URL

    /// WikiLinks 正则：[[note]] 或 [[note|alias]]
    private static let wikiLinkPattern = #"\[\[([^\]|#]+)(?:\|([^\]]+))?\]\]"#

    public init(currentFileDirectory: URL) {
        self.currentFileDirectory = currentFileDirectory
    }

    // MARK: - Image Rewriting

    public func visitImage(_ image: Markdown.Image) -> Markup? {
        guard let source = image.source else { return image }

        // 只改写本地相对路径（非 http/https）
        if isRemoteURL(source) {
            return image
        }

        let absoluteURL = currentFileDirectory
            .appendingPathComponent(source)
            .standardizedFileURL

        var newImage = image
        newImage.source = absoluteURL.absoluteString
        return newImage
    }

    // MARK: - WikiLinks Rewriting

    public func visitText(_ text: Markdown.Text) -> Markup? {
        // 策略：将 WikiLinks 语法替换为标准 Markdown 链接语法
        // [[note|alias]] → [alias](app://note/note)
        // [[note]] → [note](app://note/note)
        let raw = text.string
        let regex = try! NSRegularExpression(pattern: Self.wikiLinkPattern, options: [])
        let nsRange = NSRange(location: 0, length: (raw as NSString).length)
        guard regex.firstMatch(in: raw, options: [], range: nsRange) != nil else {
            return text
        }

        // 两轮替换：先处理带别名的，再处理普通的
        var result = raw
        // 1. [[note|alias]] → [alias](app://note/note)
        let withAliasPattern = #"\[\[([^\]|#]+)\|([^\]]+)\]\]"#
        result = result.replacingOccurrences(
            of: withAliasPattern,
            with: "[$2](app://note/$1)",
            options: .regularExpression
        )
        // 2. [[note]] → [note](app://note/note)
        let simplePattern = #"\[\[([^\]|#]+)\]\]"#
        result = result.replacingOccurrences(
            of: simplePattern,
            with: "[$1](app://note/$1)",
            options: .regularExpression
        )

        // 只有在文本被改变时才返回新节点
        if result != raw { return Text(result) }
        return text
    }

    // MARK: - Helpers

    private func isRemoteURL(_ source: String) -> Bool {
        let lowercased = source.lowercased()
        return lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://")
    }
}
