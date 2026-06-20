import SwiftUI

struct AddRepositoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var accountManager = AccountManager.shared
    @StateObject private var syncService = GitSyncService.shared
    
    @State private var repoURL = ""
    @State private var branch = "main"
    @State private var selectedAccountID: UUID? = nil // nil 表示公开仓库
    
    // OAuth 登录相关状态
    @State private var showLoginSection = false
    @State private var selectedPlatform: GitPlatform = .github
    @State private var serverURL = ""
    @State private var customClientID = ""
    
    @State private var deviceCode = ""
    @State private var userCode = ""
    @State private var verificationURI = ""
    @State private var isPolling = false
    @State private var loginErrorMessage: String? = nil
    
    @State private var isCloning = false
    @State private var cloneErrorMessage: String? = nil
    
    private var isFormValid: Bool {
        !repoURL.trimmingCharacters(in: .whitespaces).isEmpty &&
        !branch.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("repo_info".localized)) {
                    TextField("https://github.com/user/notes.git", text: $repoURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                    
                    TextField("main", text: $branch)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("auth_account".localized)) {
                    Picker("select_account".localized, selection: $selectedAccountID) {
                        Text("public_repo_no_auth".localized).tag(nil as UUID?)
                        
                        ForEach(accountManager.accounts) { account in
                            Text(account.displayName).tag(account.id as UUID?)
                        }
                    }
                    
                    Button(action: { withAnimation { showLoginSection.toggle() } }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("add_new_account".localized)
                        }
                    }
                }
                
                if showLoginSection {
                    Section(header: Text("login_new_account".localized)) {
                        Picker("platform".localized, selection: $selectedPlatform) {
                            Text("GitHub").tag(GitPlatform.github)
                            Text("GitLab").tag(GitPlatform.gitlab)
                        }
                        .pickerStyle(.segmented)
                        
                        if selectedPlatform == .gitlab {
                            TextField("https://gitlab.com", text: $serverURL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .keyboardType(.URL)
                            
                            TextField("custom_client_id_optional".localized, text: $customClientID)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        if !userCode.isEmpty {
                            VStack(alignment: .center, spacing: 12) {
                                Text("device_flow_code_prompt".localized)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                
                                Text(userCode)
                                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                                    .foregroundStyle(ClaudeColors.accent)
                                    .tracking(2)
                                    .padding()
                                    .background(ClaudeColors.tagBackground)
                                    .cornerRadius(8)
                                
                                Button(action: copyAndOpenBrowser) {
                                    Label("copy_and_open_browser".localized, systemImage: "doc.on.doc")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(ClaudeColors.text)
                                        .cornerRadius(8)
                                }
                                
                                if isPolling {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                        Text("waiting_for_auth".localized)
                                            .font(.caption)
                                            .foregroundStyle(ClaudeColors.textSecondary)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        } else {
                            Button(action: startDeviceFlow) {
                                if isPolling {
                                    ProgressView()
                                } else {
                                    Text("start_login".localized)
                                }
                            }
                            .disabled(isPolling)
                        }
                        
                        if let error = loginErrorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(ClaudeColors.accent)
                        }
                    }
                }
                
                if let error = cloneErrorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(ClaudeColors.accent)
                    }
                }
            }
            .navigationTitle("add_repo_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: startClone) {
                        if isCloning {
                            ProgressView()
                        } else {
                            Text("clone".localized)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!isFormValid || isCloning)
                }
            }
        }
    }
    
    // MARK: - OAuth Device Flow Actions
    
    private func startDeviceFlow() {
        loginErrorMessage = nil
        isPolling = true
        
        Task {
            do {
                if selectedPlatform == .github {
                    let response = try await GitHubDeviceFlowService.shared.requestDeviceCode()
                    await MainActor.run {
                        self.deviceCode = response.device_code
                        self.userCode = response.user_code
                        self.verificationURI = response.verification_uri
                    }
                    
                    // 开始轮询 Token
                    let token = try await GitHubDeviceFlowService.shared.pollForToken(
                        deviceCode: response.device_code,
                        interval: response.interval
                    )
                    
                    // 授权成功，保存账号
                    let account = try AccountManager.shared.saveAccount(
                        username: "GitHub User", // 实际开发中可以通过 API 获取真实用户名，这里简化
                        platform: .github,
                        token: token
                    )
                    
                    await MainActor.run {
                        self.selectedAccountID = account.id
                        self.showLoginSection = false
                        self.resetLoginState()
                    }
                } else {
                    let response = try await GitLabDeviceFlowService.shared.requestDeviceCode(
                        serverURL: serverURL.isEmpty ? nil : serverURL,
                        customClientID: customClientID.isEmpty ? nil : customClientID
                    )
                    await MainActor.run {
                        self.deviceCode = response.device_code
                        self.userCode = response.user_code
                        self.verificationURI = response.verification_uri
                    }
                    
                    // 开始轮询 Token
                    let token = try await GitLabDeviceFlowService.shared.pollForToken(
                        serverURL: serverURL.isEmpty ? nil : serverURL,
                        customClientID: customClientID.isEmpty ? nil : customClientID,
                        deviceCode: response.device_code,
                        interval: response.interval
                    )
                    
                    // 授权成功，保存账号
                    let account = try AccountManager.shared.saveAccount(
                        username: "GitLab User",
                        platform: .gitlab,
                        token: token,
                        serverURL: serverURL.isEmpty ? nil : serverURL
                    )
                    
                    await MainActor.run {
                        self.selectedAccountID = account.id
                        self.showLoginSection = false
                        self.resetLoginState()
                    }
                }
            } catch {
                await MainActor.run {
                    self.loginErrorMessage = error.localizedDescription
                    self.resetLoginState()
                }
            }
        }
    }
    
    private func copyAndOpenBrowser() {
        UIPasteboard.general.string = userCode
        if let url = URL(string: verificationURI) {
            UIApplication.shared.open(url)
        }
    }
    
    private func resetLoginState() {
        self.deviceCode = ""
        self.userCode = ""
        self.verificationURI = ""
        self.isPolling = false
    }
    
    // MARK: - Clone Action
    
    private func startClone() {
        cloneErrorMessage = nil
        isCloning = true
        
        let trimmedURL = repoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                try await syncService.clone(
                    repoURL: trimmedURL,
                    branch: trimmedBranch.isEmpty ? "main" : trimmedBranch,
                    accountID: selectedAccountID
                )
                await MainActor.run {
                    isCloning = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    cloneErrorMessage = error.localizedDescription
                    isCloning = false
                }
            }
        }
    }
}
