import Foundation
import SwiftLibgit2

/// Git 同步服务
/// 只读、浅克隆、每次覆盖本地 — 杜绝合并冲突
final class GitSyncService: ObservableObject, @unchecked Sendable {
    @Published var syncState: SyncState = .idle

    static let shared = GitSyncService()

    /// 仓库 URL（持久化到 UserDefaults）
    var repoURL: String {
        get { UserDefaults.standard.string(forKey: "repoURL") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "repoURL") }
    }

    /// 分支名（持久化到 UserDefaults）
    var branch: String {
        get { UserDefaults.standard.string(forKey: "repoBranch") ?? "main" }
        set { UserDefaults.standard.set(newValue, forKey: "repoBranch") }
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
        guard let url = URL(string: repoURL) else { return repoURL }
        let name = url.lastPathComponent.replacingOccurrences(of: ".git", with: "")
        return name.isEmpty ? repoURL : name
    }

    /// 是否已配置仓库（token + URL 存在即可，不要求本地仓库已克隆）
    var isConfigured: Bool {
        let hasToken = KeychainService.shared.readToken() != nil
        let hasURL = !repoURL.isEmpty
        return hasToken && hasURL
    }

    /// 本地仓库目录是否存在且是一个有效的 Git 仓库
    var isLocalRepoExists: Bool {
        let gitDir = repoRootURL.appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitDir.path)
    }

    /// 校验同步前置条件
    func validateForSync() throws {
        guard KeychainService.shared.readToken() != nil else {
            throw SyncError.unknown("token_not_found_error".localized)
        }
        guard !repoURL.isEmpty else {
            throw SyncError.unknown("repo_not_configured_error".localized)
        }
        guard isLocalRepoExists else {
            throw SyncError.unknown("local_repo_not_initialized_error".localized)
        }
    }

    /// 重置所有状态（断开连接时调用）
    func reset() {
        // 清除 UserDefaults
        UserDefaults.standard.removeObject(forKey: "repoURL")
        UserDefaults.standard.removeObject(forKey: "repoBranch")
        UserDefaults.standard.removeObject(forKey: "shallowDepth")

        // 清除 Keychain
        KeychainService.shared.deleteToken()

        // 删除本地仓库
        try? FileManager.default.removeItem(at: repoRootURL)

        // 重置同步状态
        Task { @MainActor in
            syncState = .idle
        }
    }

    /// 沙盒文档目录（Git 仓库根目录）
    var repoRootURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
    func clone(repoURL: String, branch: String = "main") async throws {
        await updateState(.syncing)

        let token = KeychainService.shared.readToken() ?? ""

        try await performGitOperation {
            try self.cloneRepository(url: repoURL, branch: branch, token: token)
        }

        // 持久化仓库信息
        self.repoURL = repoURL
        self.branch = branch

        await updateState(.success)
    }

    /// 同步（fetch + reset）
    func sync() async throws {
        await updateState(.syncing)

        try await performGitOperation {
            try self.fetchLatest()
            try self.hardReset()
        }

        await updateState(.success)
    }

    /// 提交本地修改并与云端同步（commit -> fetch -> merge -> push）
    func commitAndSync(fileURL: URL, progressHandler: @escaping @Sendable (String) -> Void) async throws {
        await updateState(.syncing)

        let relativePath = fileURL.path.replacingOccurrences(of: repoRootURL.path + "/", with: "")

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

        await updateState(.success)
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

    private func cloneRepository(url: String, branch: String, token: String) throws {
        try? FileManager.default.removeItem(at: repoRootURL)
        try FileManager.default.createDirectory(
            at: repoRootURL,
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
            localPath: repoRootURL.path,
            options: cloneOpts
        )

        guard result == .gitOK, let repo = repoPtr else {
            let gitErr = gitErrorLast()
            let detail = gitErr?.message ?? "未知错误"
            throw SyncError.unknown("clone_failed_with_detail".localized(arguments: detail, result.rawValue))
        }

        gitRepositoryFree(repo: repo)
    }

    private func fetchLatest() throws {
        var repoPtr: OpaquePointer?
        let openResult = gitRepositoryOpen(out: &repoPtr, path: repoRootURL.path)
        guard openResult == .gitOK, let repo = repoPtr else {
            let detail = gitErrorLast()?.message ?? "未知"
            throw SyncError.unknown("open_repo_failed".localized(arguments: detail))
        }
        defer { gitRepositoryFree(repo: repo) }

        var remotePtr: OpaquePointer?
        let remoteResult = gitRemoteLookup(out: &remotePtr, repo: repo, name: "origin")
        guard remoteResult == .gitOK, let remote = remotePtr else {
            let detail = gitErrorLast()?.message ?? "未知"
            throw SyncError.unknown("find_origin_failed".localized(arguments: detail))
        }
        defer { gitRemoteFree(remote: remote) }

        let token = KeychainService.shared.readToken() ?? ""
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
            throw SyncError.unknown("fetch_failed".localized(arguments: detail))
        }
    }

    private func hardReset() throws {
        var repoPtr: OpaquePointer?
        let openResult = gitRepositoryOpen(out: &repoPtr, path: repoRootURL.path)
        guard openResult == .gitOK, let repo = repoPtr else {
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
            throw SyncError.unknown("find_origin_branch_ref_failed".localized(arguments: branch, refResult.rawValue))
        }

        var commitPtr: OpaquePointer?
        let commitResult = gitCommitLookup(commit: &commitPtr, repo: repo, id: oid)
        guard commitResult == .gitOK, let commit = commitPtr else {
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
            throw SyncError.unknown("reset_failed".localized(arguments: resetResult.rawValue))
        }
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
        var repoPtr: OpaquePointer?
        let openResult = gitRepositoryOpen(out: &repoPtr, path: repoRootURL.path)
        guard openResult == .gitOK, let repo = repoPtr else {
            let detail = gitErrorLast()?.message ?? "未知"
            throw SyncError.unknown("open_repo_failed".localized(arguments: detail))
        }
        defer { gitRepositoryFree(repo: repo) }

        var indexPtr: OpaquePointer?
        let indexResult = gitRepositoryIndex(out: &indexPtr, repo: repo)
        guard indexResult == .gitOK, let index = indexPtr else {
            let detail = gitErrorLast()?.message ?? "未知"
            throw SyncError.unknown("open_index_failed".localized(arguments: detail))
        }
        defer { gitIndexFree(index: index) }

        let addResult = gitIndexAddByPath(index: index, path: relativePath)
        guard addResult == .gitOK else {
            let detail = gitErrorLast()?.message ?? "未知"
            throw SyncError.unknown("add_file_failed".localized(arguments: detail))
        }

        let writeResult = gitIndexWrite(index: index)
        guard writeResult == .gitOK else {
            let detail = gitErrorLast()?.message ?? "未知"
            throw SyncError.unknown("write_index_failed".localized(arguments: detail))
        }

        var signature = GitSignature()
        let sigResult = gitSignatureNow(out: &signature, name: "Git Reader", email: "gitreader@example.com")
        guard sigResult == .gitOK else {
            let detail = gitErrorLast()?.message ?? "未知"
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
            throw SyncError.unknown("commit_failed".localized(arguments: detail))
        }
    }

    private func mergeRemoteChanges() throws {
        var repoPtr: OpaquePointer?
        let openResult = gitRepositoryOpen(out: &repoPtr, path: repoRootURL.path)
        guard openResult == .gitOK, let repo = repoPtr else {
            let detail = gitErrorLast()?.message ?? "未知"
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
            return
        }

        var annotatedCommitPtr: OpaquePointer? = nil
        let annotatedResult = gitAnnotatedCommitLookup(out: &annotatedCommitPtr, repo: repo, id: remoteOid)
        guard annotatedResult == .gitOK, let annotatedCommit = annotatedCommitPtr else {
            let detail = gitErrorLast()?.message ?? "未知"
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
            throw SyncError.unknown("merge_analysis_failed".localized(arguments: detail))
        }

        if mergeAnalysis.contains(.gitMergeAnalysisUpToDate) {
            // Already up to date, nothing to merge
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
            throw SyncError.unknown("merge_failed".localized(arguments: detail))
        }

        // Check and resolve conflicts in index
        var indexPtr: OpaquePointer?
        let indexResult = gitRepositoryIndex(out: &indexPtr, repo: repo)
        guard indexResult == .gitOK, let index = indexPtr else {
            let detail = gitErrorLast()?.message ?? "未知"
            throw SyncError.unknown("open_index_failed".localized(arguments: detail))
        }
        defer { gitIndexFree(index: index) }

        if gitIndexHasConflicts(index: index) {
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
        let sigResult = gitSignatureNow(out: &signature, name: "Git Reader", email: "gitreader@example.com")
        guard sigResult == .gitOK else {
            let detail = gitErrorLast()?.message ?? "未知"
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
            throw SyncError.unknown("merge_commit_failed".localized(arguments: detail))
        }

        // Clean up repository state
        _ = gitRepositoryStateCleanup(repo: repo)
    }

    private func pushLatest() throws {
        var repoPtr: OpaquePointer?
        let openResult = gitRepositoryOpen(out: &repoPtr, path: repoRootURL.path)
        guard openResult == .gitOK, let repo = repoPtr else {
            let detail = gitErrorLast()?.message ?? "未知"
            throw SyncError.unknown("open_repo_failed".localized(arguments: detail))
        }
        defer { gitRepositoryFree(repo: repo) }

        var remotePtr: OpaquePointer?
        let remoteResult = gitRemoteLookup(out: &remotePtr, repo: repo, name: "origin")
        guard remoteResult == .gitOK, let remote = remotePtr else {
            let detail = gitErrorLast()?.message ?? "未知"
            throw SyncError.unknown("find_origin_failed".localized(arguments: detail))
        }
        defer { gitRemoteFree(remote: remote) }

        let token = KeychainService.shared.readToken() ?? ""
        let pushOpts = makePushOptions(token: token)

        let refspec = "refs/heads/\(branch):refs/heads/\(branch)"
        let pushResult = gitRemotePush(
            remote: remote,
            refspecs: [refspec],
            opts: pushOpts
        )

        guard pushResult == .gitOK else {
            let detail = gitErrorLast()?.message ?? "未知"
            throw SyncError.unknown("push_failed".localized(arguments: detail))
        }
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
        guard var components = URLComponents(string: repoURL) else {
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
                throw SyncError.unknown("invalid_server_response".localized)
            }
            
            switch httpResponse.statusCode {
            case 200:
                return // 测试通过
            case 401, 403:
                throw SyncError.authFailed
            case 404:
                throw SyncError.unknown("repo_does_not_exist".localized)
            default:
                throw SyncError.unknown("connection_failed_with_status".localized(arguments: httpResponse.statusCode))
            }
        } catch let error as SyncError {
            throw error
        } catch {
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
