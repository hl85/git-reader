import Foundation

/// Frontmatter 分离器
/// 在喂给 swift-markdown 前，用正则从顶部切下 YAML 块
enum FrontmatterSplitter {

    /// 分离 Markdown 文件中的 Frontmatter YAML 块和正文
    /// - Parameter rawText: 原始文件内容
    /// - Returns: NoteContent (frontmatterYAML + pureMarkdownBody)
    static func split(_ rawText: String) -> NoteContent {
        // 文件必须以 "---" 开头
        guard rawText.hasPrefix("---") else {
            return NoteContent(frontmatterYAML: nil, pureMarkdownBody: rawText)
        }

        let rest = rawText.dropFirst(3)

        // 查找结束的 "---"
        guard let endRange = rest.range(of: "\n---") else {
            return NoteContent(frontmatterYAML: nil, pureMarkdownBody: rawText)
        }

        let yamlBlock = String(rest[..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyStart = rest.index(endRange.upperBound, offsetBy: 1)
        let body = String(rest[bodyStart...]).trimmingCharacters(in: .newlines)

        return NoteContent(
            frontmatterYAML: yamlBlock,
            pureMarkdownBody: body
        )
    }
}
