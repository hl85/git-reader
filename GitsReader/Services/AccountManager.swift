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
    
    /// 移除账号，彻底清理 Keychain Token、关联仓库、本地克隆数据
    @MainActor
    func removeAccount(id: UUID) {
        // 1. 删除 Keychain 中的 Token
        KeychainService.shared.deleteToken(forAccountID: id)

        // 2. 删除该账号关联的所有仓库的本地克隆数据
        let reposToRemove = GitSyncService.shared.repositories.filter { $0.accountID == id }
        let fileManager = FileManager.default
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("repositories")
        for repo in reposToRemove {
            let repoDir = documentsDir.appendingPathComponent(repo.id.uuidString)
            try? fileManager.removeItem(at: repoDir)
        }

        // 3. 从仓库列表中移除关联该账号的仓库
        let remainingRepos = GitSyncService.shared.repositories.filter { $0.accountID != id }
        GitSyncService.shared.setRepositories(remainingRepos)

        // 4. 如果当前激活仓库被删除，切换到下一个可用仓库
        if let activeID = GitSyncService.shared.activeRepositoryID,
           reposToRemove.contains(where: { $0.id == activeID }) {
            GitSyncService.shared.setActiveRepository(remainingRepos.first?.id)
        }

        // 5. 从账号列表中移除（触发 didSet → saveAccounts）
        accounts.removeAll { $0.id == id }
    }
    
    /// 获取账号的 Token
    func getToken(forAccountID id: UUID) -> String? {
        KeychainService.shared.readToken(forAccountID: id)
    }
}
