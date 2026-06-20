import Foundation
import Yams

/// 搜索服务：内存索引构建 + 实时过滤
/// 假设仓库 < 5000 个 .md 文件，内存索引足够
final class SearchService: ObservableObject, @unchecked Sendable {
    static let shared = SearchService()

    @Published private(set) var index: [SearchIndexEntry] = []

    private let scanner = FileScannerService.shared

    private init() {}

    /// 重建搜索索引（同步或切换仓库后调用）
    func rebuildIndex() {
        rebuildIndex(from: scanner.getAllMarkdownFiles())
    }

    /// 从指定文件列表构建索引（支持测试注入，不依赖单例）
    func rebuildIndex(from files: [URL]) {
        var entries: [SearchIndexEntry] = []

        for fileURL in files {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }

            let frontmatter = parseFrontmatter(from: content)
            let title = frontmatter["title"] as? String
                ?? fileURL.deletingPathExtension().lastPathComponent
            let tags = (frontmatter["tags"] as? [String])
                ?? (frontmatter["tags"] as? String).map { [$0] }
                ?? []
            let aliases = (frontmatter["aliases"] as? [String])
                ?? (frontmatter["alias"] as? String).map { [$0] }
                ?? []

            let entry = SearchIndexEntry(
                filename: fileURL.deletingPathExtension().lastPathComponent,
                fileURL: fileURL,
                title: title,
                tags: tags,
                aliases: aliases
            )
            entries.append(entry)
        }

        if Thread.isMainThread {
            self.index = entries
        } else {
            DispatchQueue.main.async {
                self.index = entries
            }
        }
    }

    /// 搜索过滤
    /// - Parameter query: 搜索关键词
    /// - Returns: 匹配的索引条目
    func filter(query: String) -> [SearchIndexEntry] {
        guard !query.isEmpty else { return index }

        let lowercased = query.lowercased()
        return index.filter { entry in
            entry.searchableText.contains(lowercased)
        }
    }

    // MARK: - Private

    /// 快速解析 Frontmatter YAML（无完整 YAML 解析器开销）
    private func parseFrontmatter(from content: String) -> [String: Any] {
        // 1. 高性能容错：仅提取前 50 个字符进行空白字符裁剪和前缀检查
        let prefix = content.prefix(50).trimmingCharacters(in: .whitespacesAndNewlines)
        guard prefix.hasPrefix("---") else {
            return [:]
        }

        // 2. 找到真正的 Frontmatter 起始位置
        guard let startRange = content.range(of: "---") else {
            return [:]
        }

        let rest = content[startRange.upperBound...]
        guard let endRange = rest.range(of: "\n---") else {
            return [:]
        }

        let yamlBlock = String(rest[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = try? Yams.load(yaml: yamlBlock) as? [String: Any] else {
            return [:]
        }

        return parsed
    }
}
