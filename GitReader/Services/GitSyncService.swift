import Foundation
import SwiftLibgit2

/// Git 同步服务
/// 只读、浅克隆、每次覆盖本地 — 杜绝合并冲突
final class GitSyncService: ObservableObject, @unchecked Sendable {
    @Published var syncState: SyncState = .idle

    static let shared = GitSyncService()

    /// 所有已配置的仓库列表（持久化到 UserDefaults）
    var repositories: [RepositoryInfo] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "repositories"),
                  let list = try? JSONDecoder().decode([RepositoryInfo].self, from: data) else {
                return []
            }
            return list
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "repositories")
            }
        }
    }

    /// 当前激活的仓库 ID（持久化到 UserDefaults）
    var activeRepositoryID: UUID? {
        get {
            guard let str = UserDefaults.standard.string(forKey: "activeRepositoryID") else { return nil }
            return UUID(uuidString: str)
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: "activeRepositoryID")
            // 切换仓库时，通知相关服务刷新
            NotificationCenter.default.post(name: .activeRepositoryDidChange, object: nil)
        }
    }

    /// 当前激活的仓库信息
    var activeRepository: RepositoryInfo? {
        repositories.first { $0.id == activeRepositoryID }
    }

    /// 仓库 URL（兼容旧代码，动态获取当前激活仓库的 URL）
    var repoURL: String {
        get { activeRepository?.url ?? "" }
        set {
            if let activeID = activeRepositoryID {
                var list = repositories
                if let index = list.firstIndex(where: { $0.id == activeID }) {
                    list[index].url = newValue
                    repositories = list
                }
            }
        }
    }

    /// 分支名（兼容旧代码，动态获取当前激活仓库的分支）
    var branch: String {
        get { activeRepository?.branch ?? "main" }
        set {
            if let activeID = activeRepositoryID {
                var list = repositories
                if let index = list.firstIndex(where: { $0.id == activeID }) {
                    list[index].branch = newValue
                    repositories = list
                }
            }
        }
    }

    /// 浅克隆深度（0 = 完整历史，1 = 仅最新 commit）
    /// 持久化到 UserDefaults，默认 1
    var shallowDepth: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: "shallowDepth")
            return val == 0 ? 1 : val  // 默认 1
        }
        set { UserDefaults.standard.set(newValue, forKey: "shallowDepth") }
    }

    /// 仓库显示名（从 URL 提取）
    var repoDisplayName: String {
        activeRepository?.name ?? repoURL
    }

    /// 是否已配置仓库（token + URL 存在即可，不要求本地仓库已克隆）
    var isConfigured: Bool {
        guard let activeRepo = activeRepository else { return false }
        if let accountID = activeRepo.accountID {
            return KeychainService.shared.readToken(forAccountID: accountID) != nil
        }
        return true // 公开仓库不需要 token
    }

    /// 本地仓库目录是否存在且是一个有效的 Git 仓库
    var isLocalRepoExists: Bool {
        guard activeRepositoryID != nil else { return false }
        let gitDir = repoRootURL.appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitDir.path)
    }

    /// 校验同步前置条件
    func validateForSync() throws {
        guard let activeRepo = activeRepository else {
            throw SyncError.repoNotConfigured
        }
        if let accountID = activeRepo.accountID {
            guard KeychainService.shared.readToken(forAccountID: accountID) != nil else {
                throw SyncError.tokenMissing
            }
        }
        guard isLocalRepoExists else {
            throw SyncError.localRepoNotInitialized
        }
    }

    /// 重置所有状态（断开连接时调用）
    func reset() {
        guard let activeID = activeRepositoryID else { return }
        
        // 从列表中移除当前仓库
        var list = repositories
        if let index = list.firstIndex(where: { $0.id == activeID }) {
            list.remove(at: index)
            repositories = list
        }

        // 删除本地仓库目录
        try? FileManager.default.removeItem(at: repoRootURL)

        // 切换到下一个可用仓库，或者设为 nil
        activeRepositoryID = repositories.first?.id

        // 重置同步状态
        Task { @MainActor in
            syncState = .idle
        }
    }

    /// 沙盒文档目录（Git 仓库根目录）
    var repoRootURL: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("repositories")
        if let activeID = activeRepositoryID {
            return base.appendingPathComponent(activeID.uuidString)
        }
        // 兼容旧路径，避免未设置 activeRepositoryID 时崩溃
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("repo")
    }

    private init() {
        _ = gitLibgit2Init()
        // 设置系统 CA 证书，解决 OpenSSL 找不到根证书的问题
        setupSSLCertificates()
    }

    deinit {
        _ = gitLibgit2Shutdown()
    }

    // MARK: - Public API

    /// 首次克隆仓库
    func clone(repoURL: String, branch: String = "main", accountID: UUID? = nil) async throws {
        print("[GitSyncService] clone API called with URL: \(repoURL), branch: \(branch), accountID: \(String(describing: accountID))")
        await updateState(.syncing)

        let token = accountID != nil ? (KeychainService.shared.readToken(forAccountID: accountID) ?? "") : ""

        // 创建临时 UUID 用于克隆，克隆成功后再加入列表
        let tempID = UUID()
        let tempRepoURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("repositories")
            .appendingPathComponent(tempID.uuidString)

        do {
            try await performGitOperation {
                try self.cloneRepository(url: repoURL, branch: branch, token: token, targetURL: tempRepoURL)
            }

            // 克隆成功，创建并保存仓库信息
            let displayName = self.getDisplayName(from: repoURL)
            let newRepo = RepositoryInfo(id: tempID, name: displayName, url: repoURL, branch: branch, accountID: accountID)
            
            var list = repositories
            list.append(newRepo)
            repositories = list
            
            // 设为当前激活仓库
            activeRepositoryID = tempID

            print("[GitSyncService] clone API successful")
            await updateState(.success)
        } catch {
            print("[GitSyncService] clone API failed with error: \(error)")
            await updateState(.error(error as? SyncError ?? .unknown(error.localizedDescription)))
            throw error
        }
    }

    private func getDisplayName(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        let name = url.lastPathComponent.replacingOccurrences(of: ".git", with: "")
        return name.isEmpty ? urlString : name
    }

    /// 同步（fetch + reset）
    func sync() async throws {
        print("[GitSyncService] sync API called")
        await updateState(.syncing)

        do {
            try await performGitOperation {
                try self.fetchLatest()
                try self.hardReset()
            }

            print("[GitSyncService] sync API successful")
            await updateState(.success)
        } catch {
            print("[GitSyncService] sync API failed with error: \(error)")
            await updateState(.error(error as? SyncError ?? .unknown(error.localizedDescription)))
            throw error
        }
    }

    /// 提交本地修改并与云端同步（commit -> fetch -> merge -> push）
    func commitAndSync(fileURL: URL, progressHandler: @escaping @Sendable (String) -> Void) async throws {
        print("[GitSyncService] commitAndSync API called for file: \(fileURL.path)")
        await updateState(.syncing)

        let relativePath = fileURL.path.replacingOccurrences(of: repoRootURL.path + "/", with: "")

        do {
            // 0. 前置校验：在本地 commit 之前，先检查当前 Token 是否有 Push (写入) 权限
            // 这样如果无权限，可以立刻报错，避免本地产生未同步的 commit
            let token = activeRepository?.accountID != nil ? (KeychainService.shared.readToken(forAccountID: activeRepository?.accountID) ?? "") : ""
            try await checkPushPermission(repoURL: repoURL, token: token)

            try await performGitOperation {
                // 1. Commit local changes
                progressHandler("sync_committing".localized)
                try self.commitLocalChanges(relativePath: relativePath)

                // 2. Fetch remote updates
                progressHandler("sync_pulling".localized)
                try self.fetchLatest()

                // 3. Merge and resolve conflicts
                progressHandler("sync_resolving_conflicts".localized)
                try self.mergeRemoteChanges()

                // 4. Push to remote
                progressHandler("sync_pushing".localized)
                try self.pushLatest()
            }

            print("[GitSyncService] commitAndSync API successful")
            await updateState(.success)
        } catch {
            print("[GitSyncService] commitAndSync API failed with error: \(error)")
            await updateState(.error(error as? SyncError ?? .unknown(error.localizedDescription)))
            throw error
        }
    }

    // MARK: - Git Operations

    /// 认证回调：提供 username/password 凭据
    /// 通过 payload 指针传递 token 字符串
    private static let credentialCallback: GitCredentialAcquireCB = { out, url, username, allowedTypes, payload in
        guard let payload = payload else { return -1 }
        let token = Unmanaged<NSString>.fromOpaque(payload).takeUnretainedValue() as String
        return gitCredentialUserPassPlaintextNew(
            out: out!,
            username: "token",
            password: token
        ).rawValue
    }

    /// SSL 证书校验回调：始终返回 0 以信任所有证书，解决模拟器/真机下的 SSL 证书失效问题
    private static let certificateCheckCallback: GitTransportCertificateCheckCB = { cert, valid, host, payload in
        return 0
    }

    private func makeFetchOptions(token: String) -> GitFetchOptions {
        var fetchOpts = GitFetchOptions()
        if shallowDepth > 0 {
            fetchOpts.depth = GitFetchDepthT(rawValue: UInt32(shallowDepth)) ?? .gitFetchDepthFull
        }
        fetchOpts.downloadTags = .gitRemoteDownloadTagsNone

        // 设置认证回调
        if !token.isEmpty {
            let tokenBox = token as NSString
            fetchOpts.callbacks.credentials = Self.credentialCallback
            fetchOpts.callbacks.payload = Unmanaged.passUnretained(tokenBox).toOpaque()
        }
        
        // 设置证书校验回调，绕过 SSL 验证
        fetchOpts.callbacks.certificateCheck = Self.certificateCheckCallback
        
        return fetchOpts
    }

    private func cloneRepository(url: String, branch: String, token: String, targetURL: URL) throws {
        print("[GitSyncService] Start cloning repository: \(url), branch: \(branch)")
        try? FileManager.default.removeItem(at: targetURL)
        try FileManager.default.createDirectory(
            at: targetURL,
            withIntermediateDirectories: true
        )

        let authenticatedURL = embedToken(in: url, token: token)

        let fetchOpts = makeFetchOptions(token: token)

        var cloneOpts = GitCloneOptions()
        cloneOpts.fetchOpts = fetchOpts
        cloneOpts.checkoutBranch = branch

        var repoPtr: OpaquePointer?
        let result = gitClone(
            out: &repoPtr,
            url: authenticatedURL,
            localPath: targetURL.path,
            options: cloneOpts
        )

        guard result == .gitOK, let repo = repoPtr else {
            let gitErr = gitErrorLast()
            let detail = gitErr?.message ?? "未知错误"
            print("[GitSyncService] Clone failed. Result code: \(result.rawValue), Error: \(detail)")
            throw SyncError.unknown("clone_failed_with_detail".localized(arguments: detail, result.rawValue))
        }

        print("[GitSyncService] Clone successful")
        gitRepositoryFree(repo: repo)
    }

    private func fetchLatest() throws {
        print("[GitSyncService] Start fetching latest from origin, branch: \(branch)")
        var repoPtr: OpaquePointer?
        let openResult = gitRepositoryOpen(out: &repoPtr, path: repoRootURL.path)
        guard openResult == .gitOK, let repo = repoPtr else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Fetch failed: Open repository failed. Error: \(detail)")
            throw SyncError.unknown("open_repo_failed".localized(arguments: detail))
        }
        defer { gitRepositoryFree(repo: repo) }

        var remotePtr: OpaquePointer?
        let remoteResult = gitRemoteLookup(out: &remotePtr, repo: repo, name: "origin")
        guard remoteResult == .gitOK, let remote = remotePtr else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Fetch failed: Find origin failed. Error: \(detail)")
            throw SyncError.unknown("find_origin_failed".localized(arguments: detail))
        }
        defer { gitRemoteFree(remote: remote) }

        let token = activeRepository?.accountID != nil ? (KeychainService.shared.readToken(forAccountID: activeRepository?.accountID) ?? "") : ""
        let fetchOpts = makeFetchOptions(token: token)

        let refspec = "refs/heads/\(branch):refs/remotes/origin/\(branch)"

        let fetchResult = gitRemoteFetch(
            remote: remote,
            refspecs: [refspec],
            opts: fetchOpts,
            reflogMessage: nil
        )

        guard fetchResult == .gitOK else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Fetch failed. Result code: \(fetchResult.rawValue), Error: \(detail)")
            throw SyncError.unknown("fetch_failed".localized(arguments: detail))
        }
        print("[GitSyncService] Fetch successful")
    }

    private func hardReset() throws {
        print("[GitSyncService] Start hard reset to origin/\(branch)")
        var repoPtr: OpaquePointer?
        let openResult = gitRepositoryOpen(out: &repoPtr, path: repoRootURL.path)
        guard openResult == .gitOK, let repo = repoPtr else {
            print("[GitSyncService] Hard reset failed: Open repository failed. Error code: \(openResult.rawValue)")
            throw SyncError.unknown("open_repo_failed".localized(arguments: "\(openResult)"))
        }
        defer { gitRepositoryFree(repo: repo) }

        var oid = GitOID()
        let refResult = gitReferenceNameToID(
            out: &oid,
            repo: repo,
            name: "refs/remotes/origin/\(branch)"
        )
        guard refResult == .gitOK else {
            print("[GitSyncService] Hard reset failed: Find origin branch ref failed. Error code: \(refResult.rawValue)")
            throw SyncError.unknown("find_origin_branch_ref_failed".localized(arguments: branch, refResult.rawValue))
        }

        var commitPtr: OpaquePointer?
        let commitResult = gitCommitLookup(commit: &commitPtr, repo: repo, id: oid)
        guard commitResult == .gitOK, let commit = commitPtr else {
            print("[GitSyncService] Hard reset failed: Find commit failed. Error code: \(commitResult.rawValue)")
            throw SyncError.unknown("find_commit_failed".localized(arguments: commitResult.rawValue))
        }
        defer { gitCommitFree(commit: commit) }

        var checkoutOpts = GitCheckoutOptions()
        checkoutOpts.checkoutStrategy = .gitCheckoutForce

        let resetResult = gitReset(
            repo: repo,
            target: commit,
            resetType: .gitResetHard,
            checkoutOpts: checkoutOpts
        )

        guard resetResult == .gitOK else {
            print("[GitSyncService] Hard reset failed. Error code: \(resetResult.rawValue)")
            throw SyncError.unknown("reset_failed".localized(arguments: resetResult.rawValue))
        }
        print("[GitSyncService] Hard reset successful")
    }

    // MARK: - Helpers

    private func performGitOperation(_ block: @escaping @Sendable () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try block()
                    continuation.resume()
                } catch let error as SyncError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: SyncError.unknown(error.localizedDescription))
                }
            }
        }
    }

    /// 设置系统 CA 证书路径，解决 libgit2 OpenSSL 找不到根证书的问题
    private func setupSSLCertificates() {
        #if os(macOS)
        let certPaths = [
            "/etc/ssl/cert.pem",
            "/usr/local/share/certs/ca-root-nss.crt",
        ]
        for certPath in certPaths {
            if FileManager.default.fileExists(atPath: certPath) {
                _ = gitLibgit2OptSetSSLCertLocations(file: certPath, path: nil)
                return
            }
        }
        #else
        // iOS 真机与模拟器：均从 Security.framework 导出系统证书到临时文件
        exportSystemCertificates()
        #endif
    }

    /// 从 iOS Keychain 导出系统根证书到临时文件
    private func exportSystemCertificates() {
        let tempCerts = FileManager.default.temporaryDirectory
            .appendingPathComponent("system-certs.pem")

        // 如果已导出且未过期（24h），直接复用
        if let attrs = try? FileManager.default.attributesOfItem(atPath: tempCerts.path),
           let modified = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) < 86400 {
            _ = gitLibgit2OptSetSSLCertLocations(file: tempCerts.path, path: nil)
            return
        }

        var pemData = Data()
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        guard status == errSecSuccess, let certs = items as? [SecCertificate] else { return }

        for cert in certs {
            guard let der = SecCertificateCopyData(cert) as Data? else { continue }
            let base64 = der.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
            let pem = "-----BEGIN CERTIFICATE-----\n\(base64)\n-----END CERTIFICATE-----\n"
            pemData.append(pem.data(using: .utf8) ?? Data())
        }

        try? pemData.write(to: tempCerts)
        _ = gitLibgit2OptSetSSLCertLocations(file: tempCerts.path, path: nil)
    }

    private func makePushOptions(token: String) -> GitPushOptions {
        var pushOpts = GitPushOptions()
        
        // 设置认证回调
        if !token.isEmpty {
            let tokenBox = token as NSString
            pushOpts.callbacks.credentials = Self.credentialCallback
            pushOpts.callbacks.payload = Unmanaged.passUnretained(tokenBox).toOpaque()
        }
        
        // 设置证书校验回调，绕过 SSL 验证
        pushOpts.callbacks.certificateCheck = Self.certificateCheckCallback
        
        return pushOpts
    }

    private func commitLocalChanges(relativePath: String) throws {
        print("[GitSyncService] Start committing local changes for file: \(relativePath)")
        var repoPtr: OpaquePointer?
        let openResult = gitRepositoryOpen(out: &repoPtr, path: repoRootURL.path)
        guard openResult == .gitOK, let repo = repoPtr else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Commit failed: Open repository failed. Error: \(detail)")
            throw SyncError.unknown("open_repo_failed".localized(arguments: detail))
        }
        defer { gitRepositoryFree(repo: repo) }

        var indexPtr: OpaquePointer?
        let indexResult = gitRepositoryIndex(out: &indexPtr, repo: repo)
        guard indexResult == .gitOK, let index = indexPtr else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Commit failed: Open index failed. Error: \(detail)")
            throw SyncError.unknown("open_index_failed".localized(arguments: detail))
        }
        defer { gitIndexFree(index: index) }

        let addResult = gitIndexAddByPath(index: index, path: relativePath)
        guard addResult == .gitOK else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Commit failed: Add file to index failed. Error: \(detail)")
            throw SyncError.unknown("add_file_failed".localized(arguments: detail))
        }

        let writeResult = gitIndexWrite(index: index)
        guard writeResult == .gitOK else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Commit failed: Write index failed. Error: \(detail)")
            throw SyncError.unknown("write_index_failed".localized(arguments: detail))
        }

        var signature = GitSignature()
        let sigResult = gitSignatureNow(out: &signature, name: "Gits Reader", email: "gitsreader@example.com")
        guard sigResult == .gitOK else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Commit failed: Create signature failed. Error: \(detail)")
            throw SyncError.unknown("create_signature_failed".localized(arguments: detail))
        }

        let commitOpts = GitCommitCreateOptions(author: signature, committer: signature)
        var commitOid = GitOID()
        let commitResult = gitCommitCreateFromStage(
            id: &commitOid,
            repo: repo,
            message: "Update properties for \(relativePath)",
            opts: commitOpts
        )

        // .gitEUnchanged means no changes, which is fine
        guard commitResult == .gitOK || commitResult == .gitEUnchanged else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Commit failed. Result code: \(commitResult.rawValue), Error: \(detail)")
            throw SyncError.unknown("commit_failed".localized(arguments: detail))
        }
        
        if commitResult == .gitEUnchanged {
            print("[GitSyncService] Commit finished: No changes to commit (.gitEUnchanged)")
        } else {
            print("[GitSyncService] Commit successful. OID: \(commitOid)")
        }
    }

    private func mergeRemoteChanges() throws {
        print("[GitSyncService] Start merging remote changes from origin/\(branch)")
        var repoPtr: OpaquePointer?
        let openResult = gitRepositoryOpen(out: &repoPtr, path: repoRootURL.path)
        guard openResult == .gitOK, let repo = repoPtr else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Merge failed: Open repository failed. Error: \(detail)")
            throw SyncError.unknown("open_repo_failed".localized(arguments: detail))
        }
        defer { gitRepositoryFree(repo: repo) }

        var remoteOid = GitOID()
        let refResult = gitReferenceNameToID(
            out: &remoteOid,
            repo: repo,
            name: "refs/remotes/origin/\(branch)"
        )
        guard refResult == .gitOK else {
            // If remote branch ref doesn't exist, nothing to merge
            print("[GitSyncService] Merge: Remote branch ref refs/remotes/origin/\(branch) does not exist, skipping merge.")
            return
        }

        var annotatedCommitPtr: OpaquePointer? = nil
        let annotatedResult = gitAnnotatedCommitLookup(out: &annotatedCommitPtr, repo: repo, id: remoteOid)
        guard annotatedResult == .gitOK, let annotatedCommit = annotatedCommitPtr else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Merge failed: Lookup annotated commit failed. Error: \(detail)")
            throw SyncError.unknown("lookup_annotated_commit_failed".localized(arguments: detail))
        }
        defer { gitAnnotatedCommitFree(commit: annotatedCommit) }

        var mergeAnalysis: GitMergeAnalysisT = .gitMergeAnalysisNone
        var mergePreference: GitMergePreferenceT = .gitMergePreferenceNone
        var theirHeads: [OpaquePointer?] = [annotatedCommit]
        let analysisResult = gitMergeAnalysis(
            analysisOut: &mergeAnalysis,
            preferenceOut: &mergePreference,
            repo: repo,
            theirHeads: &theirHeads,
            theirHeadsLen: 1
        )
        guard analysisResult == .gitOK else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Merge failed: Merge analysis failed. Error: \(detail)")
            throw SyncError.unknown("merge_analysis_failed".localized(arguments: detail))
        }

        print("[GitSyncService] Merge analysis result: \(mergeAnalysis.rawValue), preference: \(mergePreference.rawValue)")

        if mergeAnalysis.contains(.gitMergeAnalysisUpToDate) {
            // Already up to date, nothing to merge
            print("[GitSyncService] Merge: Already up to date, skipping merge.")
            return
        }

        // Perform merge favoring ours (local)
        var mergeOpts = GitMergeOptions()
        mergeOpts.fileFavor = .gitMergeFileFavorOurs

        var checkoutOpts = GitCheckoutOptions()
        checkoutOpts.checkoutStrategy = .gitCheckoutForce

        let mergeResult = gitMerge(
            repo: repo,
            theirHeads: &theirHeads,
            theirHeadsLen: 1,
            mergeOpts: mergeOpts,
            checkoutOpts: checkoutOpts
        )
        guard mergeResult == .gitOK else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Merge failed. Result code: \(mergeResult.rawValue), Error: \(detail)")
            throw SyncError.unknown("merge_failed".localized(arguments: detail))
        }

        // Check and resolve conflicts in index
        var indexPtr: OpaquePointer?
        let indexResult = gitRepositoryIndex(out: &indexPtr, repo: repo)
        guard indexResult == .gitOK, let index = indexPtr else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Merge failed: Open index failed. Error: \(detail)")
            throw SyncError.unknown("open_index_failed".localized(arguments: detail))
        }
        defer { gitIndexFree(index: index) }

        if gitIndexHasConflicts(index: index) {
            print("[GitSyncService] Merge: Conflicts detected in index, resolving conflicts favoring local...")
            var iteratorPointer: OpaquePointer? = nil
            let iterResult = gitIndexConflictIteratorNew(iteratorOut: &iteratorPointer, index: index)
            if iterResult == .gitOK, let iterator = iteratorPointer {
                defer { gitIndexConflictIteratorFree(iterator: iterator) }
                
                var ancestorIndexEntry = GitIndexEntry()
                var ourIndexEntry = GitIndexEntry()
                var theirIndexEntry = GitIndexEntry()
                
                while true {
                    let nextResult = gitIndexConflictNext(
                        ancestorOut: &ancestorIndexEntry,
                        ourOut: &ourIndexEntry,
                        theirOut: &theirIndexEntry,
                        iterator: iterator
                    )
                    if nextResult == .gitIterOver {
                        break
                    }
                    guard nextResult == .gitOK else { break }
                    
                    let conflictPath = !ourIndexEntry.path.isEmpty ? ourIndexEntry.path : (!theirIndexEntry.path.isEmpty ? theirIndexEntry.path : ancestorIndexEntry.path)
                    print("[GitSyncService] Resolving conflict for path: \(conflictPath)")
                    
                    if !ourIndexEntry.path.isEmpty {
                        _ = gitIndexAddByPath(index: index, path: ourIndexEntry.path)
                    } else if !theirIndexEntry.path.isEmpty {
                        _ = gitIndexRemoveByPath(index: index, path: theirIndexEntry.path)
                    } else if !ancestorIndexEntry.path.isEmpty {
                        _ = gitIndexRemoveByPath(index: index, path: ancestorIndexEntry.path)
                    }
                }
                _ = gitIndexWrite(index: index)
            }
        }

        // Commit the merge
        var signature = GitSignature()
        let sigResult = gitSignatureNow(out: &signature, name: "Gits Reader", email: "gitsreader@example.com")
        guard sigResult == .gitOK else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Merge failed: Create signature failed. Error: \(detail)")
            throw SyncError.unknown("create_signature_failed".localized(arguments: detail))
        }

        let commitOpts = GitCommitCreateOptions(author: signature, committer: signature)
        var mergeCommitOid = GitOID()
        let commitResult = gitCommitCreateFromStage(
            id: &mergeCommitOid,
            repo: repo,
            message: "Merge remote-tracking branch 'origin/\(branch)' (resolved conflicts favoring local)",
            opts: commitOpts
        )
        guard commitResult == .gitOK || commitResult == .gitEUnchanged else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Merge commit failed. Result code: \(commitResult.rawValue), Error: \(detail)")
            throw SyncError.unknown("merge_commit_failed".localized(arguments: detail))
        }

        // Clean up repository state
        _ = gitRepositoryStateCleanup(repo: repo)
        print("[GitSyncService] Merge successful. Commit OID: \(mergeCommitOid)")
    }

    private func pushLatest() throws {
        print("[GitSyncService] Start pushing to origin, branch: \(branch)")
        var repoPtr: OpaquePointer?
        let openResult = gitRepositoryOpen(out: &repoPtr, path: repoRootURL.path)
        guard openResult == .gitOK, let repo = repoPtr else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Push failed: Open repository failed. Error: \(detail)")
            throw SyncError.unknown("open_repo_failed".localized(arguments: detail))
        }
        defer { gitRepositoryFree(repo: repo) }

        var remotePtr: OpaquePointer?
        let remoteResult = gitRemoteLookup(out: &remotePtr, repo: repo, name: "origin")
        guard remoteResult == .gitOK, let remote = remotePtr else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Push failed: Find origin failed. Error: \(detail)")
            throw SyncError.unknown("find_origin_failed".localized(arguments: detail))
        }
        defer { gitRemoteFree(remote: remote) }

        let token = activeRepository?.accountID != nil ? (KeychainService.shared.readToken(forAccountID: activeRepository?.accountID) ?? "") : ""
        let pushOpts = makePushOptions(token: token)

        let refspec = "refs/heads/\(branch):refs/heads/\(branch)"
        let pushResult = gitRemotePush(
            remote: remote,
            refspecs: [refspec],
            opts: pushOpts
        )

        guard pushResult == .gitOK else {
            let detail = gitErrorLast()?.message ?? "未知"
            print("[GitSyncService] Push failed. Result code: \(pushResult.rawValue), Error: \(detail)")
            throw SyncError.unknown("push_failed".localized(arguments: detail))
        }
        print("[GitSyncService] Push successful")
    }

    private func embedToken(in urlString: String, token: String) -> String {
        guard !token.isEmpty,
              var components = URLComponents(string: urlString),
              components.host != nil else {
            return urlString
        }
        components.user = "token"
        components.password = token
        return components.url?.absoluteString ?? urlString
    }

    /// 测试连接（使用 HTTP Session 级别的连接测试）
    func testConnection(repoURL: String, token: String, session: URLSession = .shared) async throws {
        print("[GitSyncService] Start connection test for URL: \(repoURL)")
        guard var components = URLComponents(string: repoURL) else {
            print("[GitSyncService] Connection test failed: Invalid repo URL")
            throw SyncError.unknown("invalid_repo_url".localized)
        }
        
        // 规范化路径，确保以 /info/refs 结尾
        if components.path.hasSuffix(".git") {
            components.path += "/info/refs"
        } else {
            if !components.path.hasSuffix("/") {
                components.path += "/"
            }
            components.path += "info/refs"
        }
        
        components.queryItems = [URLQueryItem(name: "service", value: "git-upload-pack")]
        
        guard let url = components.url else {
            print("[GitSyncService] Connection test failed: Cannot build test URL")
            throw SyncError.unknown("cannot_build_test_url".localized)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0 // 10秒超时
        
        if !token.isEmpty {
            let credentialString = "token:\(token)"
            if let credentialData = credentialString.data(using: .utf8) {
                let base64Credentials = credentialData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }
        
        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[GitSyncService] Connection test failed: Invalid server response")
                throw SyncError.unknown("invalid_server_response".localized)
            }
            
            print("[GitSyncService] Connection test HTTP status code: \(httpResponse.statusCode)")
            switch httpResponse.statusCode {
            case 200:
                print("[GitSyncService] Connection test successful")
                return // 测试通过
            case 401, 403:
                print("[GitSyncService] Connection test failed: Auth failed")
                throw SyncError.authFailed
            case 404:
                print("[GitSyncService] Connection test failed: Repo does not exist")
                throw SyncError.unknown("repo_does_not_exist".localized)
            default:
                print("[GitSyncService] Connection test failed with status: \(httpResponse.statusCode)")
                throw SyncError.unknown("connection_failed_with_status".localized(arguments: httpResponse.statusCode))
            }
        } catch let error as SyncError {
            throw error
        } catch {
            print("[GitSyncService] Connection test failed with error: \(error.localizedDescription)")
            throw SyncError.unknown("connection_test_failed_with_error".localized(arguments: error.localizedDescription))
        }
    }

    /// 检查当前 Token 是否对仓库有 Push (写入) 权限
    func checkPushPermission(repoURL: String, token: String, session: URLSession = .shared) async throws {
        print("[GitSyncService] Checking push permission for URL: \(repoURL)")
        guard var components = URLComponents(string: repoURL) else {
            print("[GitSyncService] Push permission check failed: Invalid repo URL")
            throw SyncError.unknown("invalid_repo_url".localized)
        }
        
        // 规范化路径，确保以 /info/refs 结尾
        if components.path.hasSuffix(".git") {
            components.path += "/info/refs"
        } else {
            if !components.path.hasSuffix("/") {
                components.path += "/"
            }
            components.path += "info/refs"
        }
        
        // 使用 git-receive-pack 探测写权限
        components.queryItems = [URLQueryItem(name: "service", value: "git-receive-pack")]
        
        guard let url = components.url else {
            print("[GitSyncService] Push permission check failed: Cannot build test URL")
            throw SyncError.unknown("cannot_build_test_url".localized)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0 // 10秒超时
        
        if !token.isEmpty {
            let credentialString = "token:\(token)"
            if let credentialData = credentialString.data(using: .utf8) {
                let base64Credentials = credentialData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }
        
        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[GitSyncService] Push permission check failed: Invalid server response")
                throw SyncError.unknown("invalid_server_response".localized)
            }
            
            print("[GitSyncService] Push permission check HTTP status code: \(httpResponse.statusCode)")
            switch httpResponse.statusCode {
            case 200:
                print("[GitSyncService] Push permission check successful: Has write permission")
                return // 拥有写权限
            case 401, 403:
                print("[GitSyncService] Push permission check failed: No write permission (401/403)")
                throw SyncError.authFailed
            case 404:
                print("[GitSyncService] Push permission check failed: Repo does not exist")
                throw SyncError.unknown("repo_does_not_exist".localized)
            default:
                print("[GitSyncService] Push permission check failed with status: \(httpResponse.statusCode)")
                throw SyncError.unknown("connection_failed_with_status".localized(arguments: httpResponse.statusCode))
            }
        } catch let error as SyncError {
            throw error
        } catch {
            print("[GitSyncService] Push permission check failed with error: \(error.localizedDescription)")
            throw SyncError.unknown("connection_test_failed_with_error".localized(arguments: error.localizedDescription))
        }
    }

    @MainActor
    private func updateState(_ state: SyncState) {
        syncState = state
    }
}

/// Git 操作错误
enum GitError: Error {
    case authentication
    case network
    case generic(String)
}
