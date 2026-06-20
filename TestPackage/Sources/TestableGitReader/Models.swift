import Foundation

/// Frontmatter 分离结果
public struct NoteContent {
    public let frontmatterYAML: String?
    public let pureMarkdownBody: String

    public init(frontmatterYAML: String?, pureMarkdownBody: String) {
        self.frontmatterYAML = frontmatterYAML
        self.pureMarkdownBody = pureMarkdownBody
    }
}

/// 仓库配置
struct RepoConfig: Codable {
    let url: String
    let branch: String
    let repoName: String
}

/// 搜索索引条目
public struct SearchIndexEntry: Identifiable, Equatable {
    public let id: String = UUID().uuidString
    public let filename: String
    public let fileURL: URL
    public let title: String
    public let tags: [String]
    public let aliases: [String]

    public init(filename: String, fileURL: URL, title: String, tags: [String], aliases: [String]) {
        self.filename = filename
        self.fileURL = fileURL
        self.title = title
        self.tags = tags
        self.aliases = aliases
    }

    /// 所有可搜索文本的集合
    public var searchableText: String {
        ([filename, title] as [String] + tags + aliases)
            .joined(separator: " ")
            .lowercased()
    }
}

/// 文件节点（用于目录树）
struct FileItem: Identifiable, Equatable {
    let id: String = UUID().uuidString
    let name: String
    let url: URL
    let isDirectory: Bool
    var tags: [String] = []
    var status: String? = nil
}

/// 文件夹节点
struct FolderNode: Identifiable, Equatable {
    var id: String { name }
    let name: String
    var children: [FileItem]

    static func == (lhs: FolderNode, rhs: FolderNode) -> Bool {
        lhs.id == rhs.id
    }
}

/// 同步状态
enum SyncState {
    case idle
    case syncing
    case success
    case offline
    case error(SyncError)
}

public enum SyncError: LocalizedError {
    case authFailed
    case networkUnreachable
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .authFailed:
            return "认证失败，请检查 Token 是否正确"
        case .networkUnreachable:
            return "网络不可达，已切换到离线模式"
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Markdown Block Classification

/// 代码块数据
public struct CodeBlockData: Equatable {
    public let code: String
    public let language: String  // 原始语言（小写），空则为 "plaintext"

    public init(code: String, language: String) {
        self.code = code
        self.language = language
    }
}

/// 表格数据
public struct TableData: Equatable {
    public let headers: [String]
    public let rows: [[String]]

    public init(headers: [String], rows: [[String]]) {
        self.headers = headers
        self.rows = rows
    }
}

/// 块元素分类结果（用于驱动 SwiftUI 渲染分发）
public enum BlockElement: Equatable {
    case heading(level: Int, text: String)
    case paragraph
    case unorderedList(depth: Int)
    case orderedList(depth: Int)
    case codeBlock(CodeBlockData)
    case blockquote(children: [BlockElement])
    case table(TableData)
    case thematicBreak
    case unknown
}
