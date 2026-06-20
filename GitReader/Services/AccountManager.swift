import Foundation

final class AccountManager: ObservableObject, @unchecked Sendable {
    static let shared = AccountManager()
    
    @Published var accounts: [AccountInfo] = [] {
        didSet {
            saveAccounts()
        }
    }
    
    private init() {
        loadAccounts()
    }
    
    /// 从 UserDefaults 加载账号列表
    private func loadAccounts() {
        guard let data = UserDefaults.standard.data(forKey: "accounts"),
              let list = try? JSONDecoder().decode([AccountInfo].self, from: data) else {
            self.accounts = []
            return
        }
        self.accounts = list
    }
    
    /// 保存账号列表到 UserDefaults
    private func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: "accounts")
        }
    }
    
    /// 添加或更新账号，并安全存储 Token
    func saveAccount(username: String, platform: GitPlatform, token: String, serverURL: String? = nil) throws -> AccountInfo {
        // 检查是否已存在相同平台和用户名的账号
        let existingAccount = accounts.first { 
            $0.platform == platform && 
            $0.username.lowercased() == username.lowercased() && 
            $0.serverURL?.lowercased() == serverURL?.lowercased()
        }
        
        let account: AccountInfo
        if let existing = existingAccount {
            account = existing
        } else {
            account = AccountInfo(id: UUID(), username: username, platform: platform, serverURL: serverURL)
            accounts.append(account)
        }
        
        // 将 Token 存储到 Keychain，使用 account.id 隔离
        try KeychainService.shared.saveToken(token, forAccountID: account.id)
        
        return account
    }
    
    /// 移除账号，并清理 Keychain 中的 Token
    func removeAccount(id: UUID) {
        accounts.removeAll { $0.id == id }
        KeychainService.shared.deleteToken(forAccountID: id)
        
        // 同时将关联了该账号的仓库设为公开仓库（accountID = nil）
        var repos = GitSyncService.shared.repositories
        var changed = false
        for i in 0..<repos.count {
            if repos[i].accountID == id {
                repos[i].accountID = nil
                changed = true
            }
        }
        if changed {
            GitSyncService.shared.setRepositories(repos)
        }
    }
    
    /// 获取账号的 Token
    func getToken(forAccountID id: UUID) -> String? {
        KeychainService.shared.readToken(forAccountID: id)
    }
}
