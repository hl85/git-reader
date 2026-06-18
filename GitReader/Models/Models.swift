import Foundation

/// Frontmatter 分离结果
struct NoteContent {
    let frontmatterYAML: String?
    let pureMarkdownBody: String
}

/// 仓库配置
struct RepoConfig: Codable {
    let url: String
    let branch: String
    let repoName: String
}

/// 搜索索引条目
struct SearchIndexEntry: Identifiable, Equatable {
    let id: String = UUID().uuidString
    let filename: String
    let fileURL: URL
    let title: String
    let tags: [String]
    let aliases: [String]

    /// 所有可搜索文本的集合
    var searchableText: String {
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
enum SyncState: Equatable {
    case idle
    case syncing
    case success
    case offline
    case error(SyncError)

    static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.success, .success), (.offline, .offline):
            return true
        case (.error(let l), .error(let r)):
            return l.localizedDescription == r.localizedDescription
        default:
            return false
        }
    }
}

enum SyncError: LocalizedError {
    case authFailed
    case networkUnreachable
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .authFailed:
            return "auth_failed_error".localized
        case .networkUnreachable:
            return "network_unreachable_error".localized
        case .unknown(let message):
            return message
        }
    }
}
