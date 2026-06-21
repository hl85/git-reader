import Foundation
import Markdown
import Yams

/// Markdown 渲染管线
/// 串联：Frontmatter 分离 → Obsidian Rewriter → AST Document 解析
struct MarkdownPipeline {

    /// 处理结果
    struct Result {
        let frontmatter: [String: Any]
        let document: Markdown.Document
    }

    /// 处理 .md 文件
    /// - Parameters:
    ///   - fileURL: .md 文件在沙盒中的 URL
    /// - Returns: 包含 Frontmatter 字典和 AST Document 的结果
    static func process(fileAt fileURL: URL) -> Result? {
        guard let rawText = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }
        return process(rawText: rawText, fileURL: fileURL)
    }

    /// 处理原始文本
    static func process(rawText: String, fileURL: URL) -> Result? {
        // 1. 分离 Frontmatter
        let noteContent = FrontmatterSplitter.split(rawText)

        // 2. 解析 Frontmatter YAML → 字典
        let frontmatter = parseFrontmatter(noteContent.frontmatterYAML)

        // 3. 确定当前文件目录（用于图片路径改写）
        let directory = fileURL.deletingLastPathComponent()

        // 4. swift-markdown 解析 AST
        let rawDocument = Document(
            parsing: noteContent.pureMarkdownBody
        )

        // 5. Obsidian Rewriter 改写 AST
        var rewriter = ObsidianElementRewriter(currentFileDirectory: directory)
        let rewrittenDocument = rewriter.visit(rawDocument) as? Document ?? rawDocument

        return Result(
            frontmatter: frontmatter,
            document: rewrittenDocument
        )
    }

    /// 仅获取正文的 AttributedString（跳过 Frontmatter 解析）
    static func processBody(rawText: String, fileURL: URL) -> Document {
        let noteContent = FrontmatterSplitter.split(rawText)
        let directory = fileURL.deletingLastPathComponent()

        let rawDocument = Document(parsing: noteContent.pureMarkdownBody)
        var rewriter = ObsidianElementRewriter(currentFileDirectory: directory)
        return rewriter.visit(rawDocument) as? Document ?? rawDocument
    }

    // MARK: - Private

    private static func parseFrontmatter(_ yaml: String?) -> [String: Any] {
        guard let yaml = yaml, !yaml.isEmpty else {
            return [:]
        }
        return (try? Yams.load(yaml: yaml) as? [String: Any]) ?? [:]
    }
}
