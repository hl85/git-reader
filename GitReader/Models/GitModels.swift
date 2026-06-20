import Foundation

/// 支持的 Git 平台
enum GitPlatform: String, Codable, CaseIterable, Identifiable {
    case github
    case gitlab
    case generic // 普通 Git 仓库（仅支持 PAT 密码认证）

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .github: return "GitHub"
        case .gitlab: return "GitLab"
        case .generic: return "Generic Git"
        }
    }
}

/// 账号模型（存储在 UserDefaults，Token 存储在 Keychain）
struct AccountInfo: Codable, Identifiable, Hashable {
    let id: UUID             // 用于 Keychain Account 隔离
    var username: String       // 平台用户名（如 hl13571）
    var platform: GitPlatform
    var serverURL: String?     // 针对私有部署 GitLab 的实例地址（如 https://gitlab.company.com）

    var displayName: String {
        if let serverURL = serverURL, let host = URL(string: serverURL)?.host {
            return "\(username) (\(host))"
        }
        return "\(username) (\(platform.displayName))"
    }
}

/// 仓库模型（存储在 UserDefaults）
struct RepositoryInfo: Codable, Identifiable, Hashable {
    let id: UUID             // 用于本地沙盒目录隔离 (repositories/id/)
    var name: String         // 仓库显示名称
    var url: String          // Git 远程 URL
    var branch: String       // 同步分支
    var accountID: UUID?     // 关联的账号 ID（若为 nil 则表示无需认证的公开仓库）
}

extension Notification.Name {
    static let activeRepositoryDidChange = Notification.Name("activeRepositoryDidChange")
}
