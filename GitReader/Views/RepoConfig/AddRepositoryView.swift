import SwiftUI

struct UnifiedRepo: Identifiable, Hashable {
    let id: String
    let name: String
    let fullName: String
    let cloneURL: String
    let isPrivate: Bool
}

struct ClaudeCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(ClaudeTypography.cardPadding)
        .background(ClaudeColors.cardBackground)
        .cornerRadius(ClaudeTypography.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: ClaudeTypography.cardCornerRadius)
                .stroke(ClaudeColors.border, lineWidth: ClaudeTypography.cardBorderWidth)
        )
    }
}

struct AddRepositoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var accountManager = AccountManager.shared
    @StateObject private var syncService = GitSyncService.shared
    
    @State private var repoURL = ""
    @State private var branch = "main"
    @State private var selectedAccountID: UUID? = nil // nil 表示公开仓库
    
    // 绑定账号下的仓库和分支选择状态
    @State private var repos: [UnifiedRepo] = []
    @State private var selectedRepo: UnifiedRepo? = nil
    @State private var branches: [String] = []
    @State private var selectedBranch = ""
    
    @State private var isLoadingRepos = false
    @State private var isLoadingBranches = false
    @State private var repoErrorMessage: String? = nil
    @State private var branchErrorMessage: String? = nil
    
    // OAuth 登录相关状态
    @State private var showLoginSection = false
    @State private var selectedPlatform: GitPlatform = .github
    @State private var serverURL = ""
    @State private var customClientID = ""
    
    enum LoginMethod: String, CaseIterable, Identifiable {
        case deviceFlow
        case token
        
        var id: String { self.rawValue }
        
        var displayName: String {
            switch self {
            case .deviceFlow: return "device_flow_login".localized
            case .token: return "token_login".localized
            }
        }
    }
    
    @State private var selectedLoginMethod: LoginMethod = .deviceFlow
    @State private var inputToken = ""
    @State private var isVerifyingToken = false
    
    @State private var deviceCode = ""
    @State private var userCode = ""
    @State private var verificationURI = ""
    @State private var isPolling = false
    @State private var loginErrorMessage: String? = nil
    
    @State private var isCloning = false
    @State private var cloneErrorMessage: String? = nil
    
    // 自定义下拉列表展开状态（替代 Picker，避免 iPad sheet 内 popover 冲突）
    @State private var showRepoDropdown = false
    @State private var showBranchDropdown = false
    
    private var isFormValid: Bool {
        if selectedAccountID == nil {
            return !repoURL.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !branch.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return selectedRepo != nil && !selectedBranch.isEmpty
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. 账号选择列表
                    VStack(alignment: .leading, spacing: 8) {
                        Text("auth_account".localized)
                            .font(ClaudeTypography.captionFont)
                            .foregroundStyle(ClaudeColors.textSecondary)
                            .textCase(.uppercase)
                        
                        ClaudeCard {
                            VStack(spacing: 0) {
                                // 公开仓库选项
                                Button(action: {
                                    withAnimation {
                                        selectedAccountID = nil
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "globe")
                                            .font(.system(size: 16))
                                            .foregroundStyle(ClaudeColors.textSecondary)
                                            .frame(width: 24)
                                        
                                        Text("public_repo_no_auth".localized)
                                            .font(ClaudeTypography.bodyFont)
                                            .foregroundStyle(ClaudeColors.text)
                                        
                                        Spacer()
                                        
                                        if selectedAccountID == nil {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(ClaudeColors.accent)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                
                                // 已登录账号列表
                                ForEach(accountManager.accounts) { account in
                                    Divider()
                                        .background(ClaudeColors.border)
                                    
                                    Button(action: {
                                        withAnimation {
                                            selectedAccountID = account.id
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: account.platform == .github ? "person.crop.circle" : "person.crop.circle")
                                                .font(.system(size: 16))
                                                .foregroundStyle(ClaudeColors.textSecondary)
                                                .frame(width: 24)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(account.username)
                                                    .font(ClaudeTypography.bodyFont.weight(.medium))
                                                    .foregroundStyle(ClaudeColors.text)
                                                Text(account.platform.displayName)
                                                    .font(ClaudeTypography.captionFont)
                                                    .foregroundStyle(ClaudeColors.textSecondary)
                                            }
                                            
                                            Spacer()
                                            
                                            if selectedAccountID == account.id {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(ClaudeColors.accent)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Divider()
                                    .background(ClaudeColors.border)
                                
                                // 添加新账号按钮
                                Button(action: { withAnimation { showLoginSection.toggle() } }) {
                                    HStack {
                                        Image(systemName: "person.badge.plus")
                                            .font(.system(size: 16))
                                            .frame(width: 24)
                                        Text("add_new_account".localized)
                                            .font(ClaudeTypography.bodyFont.weight(.semibold))
                                        Spacer()
                                        Image(systemName: showLoginSection ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundStyle(ClaudeColors.textMuted)
                                    }
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(ClaudeColors.accent)
                            }
                        }
                    }
                    
                    // 2. 登录新账号卡片 (如果 showLoginSection 为 true)
                    if showLoginSection {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("login_new_account".localized)
                                .font(ClaudeTypography.captionFont)
                                .foregroundStyle(ClaudeColors.textSecondary)
                                .textCase(.uppercase)
                            
                            ClaudeCard {
                                Picker("platform".localized, selection: $selectedPlatform) {
                                    Text("GitHub").tag(GitPlatform.github)
                                    Text("GitLab").tag(GitPlatform.gitlab)
                                }
                                .pickerStyle(.segmented)
                                
                                Picker("login_method", selection: $selectedLoginMethod) {
                                    ForEach(LoginMethod.allCases) { method in
                                        Text(method.displayName).tag(method)
                                    }
                                }
                                .pickerStyle(.segmented)
                                
                                if selectedPlatform == .gitlab {
                                    TextField("https://gitlab.com", text: $serverURL)
                                        .font(ClaudeTypography.codeFont)
                                        .padding(10)
                                        .background(ClaudeColors.background)
                                        .cornerRadius(6)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(ClaudeColors.border, lineWidth: 1))
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .keyboardType(.URL)
                                    
                                    if selectedLoginMethod == .deviceFlow {
                                        TextField("custom_client_id_optional".localized, text: $customClientID)
                                            .font(ClaudeTypography.codeFont)
                                            .padding(10)
                                            .background(ClaudeColors.background)
                                            .cornerRadius(6)
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(ClaudeColors.border, lineWidth: 1))
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                    }
                                }
                                
                                if selectedLoginMethod == .deviceFlow {
                                    if !userCode.isEmpty {
                                        VStack(alignment: .center, spacing: 12) {
                                            Text("device_flow_code_prompt".localized)
                                                .font(ClaudeTypography.captionFont)
                                                .foregroundStyle(ClaudeColors.textSecondary)
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
                                                    .font(ClaudeTypography.bodyFont.weight(.semibold))
                                                    .foregroundStyle(ClaudeColors.background)
                                                    .frame(maxWidth: .infinity)
                                                    .frame(height: 44)
                                                    .background(ClaudeColors.text)
                                                    .cornerRadius(8)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            if isPolling {
                                                HStack(spacing: 8) {
                                                    ProgressView()
                                                    Text("waiting_for_auth".localized)
                                                        .font(ClaudeTypography.captionFont)
                                                        .foregroundStyle(ClaudeColors.textSecondary)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    } else {
                                        Button(action: startDeviceFlow) {
                                            HStack {
                                                Spacer()
                                                if isPolling {
                                                    ProgressView()
                                                } else {
                                                    Text("start_login".localized)
                                                        .font(ClaudeTypography.bodyFont.weight(.semibold))
                                                }
                                                Spacer()
                                            }
                                            .foregroundStyle(ClaudeColors.background)
                                            .frame(height: 44)
                                            .background(ClaudeColors.text)
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(isPolling)
                                    }
                                } else {
                                    SecureField("enter_token_placeholder".localized, text: $inputToken)
                                        .font(ClaudeTypography.codeFont)
                                        .padding(10)
                                        .background(ClaudeColors.background)
                                        .cornerRadius(6)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(ClaudeColors.border, lineWidth: 1))
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                    
                                    Button(action: startTokenLogin) {
                                        HStack {
                                            Spacer()
                                            if isVerifyingToken {
                                                ProgressView()
                                            } else {
                                                Text("verify_and_login".localized)
                                                    .font(ClaudeTypography.bodyFont.weight(.semibold))
                                            }
                                            Spacer()
                                        }
                                        .foregroundStyle(ClaudeColors.background)
                                        .frame(height: 44)
                                        .background(ClaudeColors.text)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(inputToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isVerifyingToken)
                                }
                                
                                if let error = loginErrorMessage {
                                    Text(error)
                                        .font(ClaudeTypography.captionFont)
                                        .foregroundStyle(ClaudeColors.accent)
                                }
                            }
                        }
                    }
                    
                    // 3. 仓库信息卡片
                    VStack(alignment: .leading, spacing: 8) {
                        Text("repo_info".localized)
                            .font(ClaudeTypography.captionFont)
                            .foregroundStyle(ClaudeColors.textSecondary)
                            .textCase(.uppercase)
                        
                        ClaudeCard {
                            if selectedAccountID == nil {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("repo_address".localized)
                                        .font(ClaudeTypography.captionFont)
                                        .foregroundStyle(ClaudeColors.textSecondary)
                                    
                                    TextField("https://github.com/username/repo.git", text: $repoURL)
                                        .font(ClaudeTypography.codeFont)
                                        .padding(10)
                                        .background(ClaudeColors.background)
                                        .cornerRadius(6)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(ClaudeColors.border, lineWidth: 1))
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .keyboardType(.URL)
                                    
                                    Text("repo_branch".localized)
                                        .font(ClaudeTypography.captionFont)
                                        .foregroundStyle(ClaudeColors.textSecondary)
                                    
                                    TextField("main", text: $branch)
                                        .font(ClaudeTypography.codeFont)
                                        .padding(10)
                                        .background(ClaudeColors.background)
                                        .cornerRadius(6)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(ClaudeColors.border, lineWidth: 1))
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                            } else {
                                if isLoadingRepos {
                                    HStack {
                                        ProgressView()
                                            .padding(.trailing, 8)
                                        Text("loading_repos".localized)
                                            .font(ClaudeTypography.bodyFont)
                                            .foregroundStyle(ClaudeColors.textSecondary)
                                    }
                                } else if let error = repoErrorMessage {
                                    Text(error)
                                        .font(ClaudeTypography.captionFont)
                                        .foregroundStyle(ClaudeColors.accent)
                                } else {
                                    // 仓库选择（自定义下拉列表）
                                    VStack(spacing: 0) {
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                showRepoDropdown.toggle()
                                                showBranchDropdown = false
                                            }
                                        }) {
                                            HStack {
                                                Text("select_repo".localized)
                                                    .font(ClaudeTypography.bodyFont)
                                                    .foregroundStyle(ClaudeColors.text)
                                                Spacer()
                                                Text(selectedRepo?.fullName ?? "please_select".localized)
                                                    .font(ClaudeTypography.bodyFont)
                                                    .foregroundStyle(selectedRepo != nil ? ClaudeColors.link : ClaudeColors.textMuted)
                                                    .lineLimit(1)
                                                    .truncationMode(.tail)
                                                Image(systemName: showRepoDropdown ? "chevron.up" : "chevron.down")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(ClaudeColors.textMuted)
                                            }
                                            .contentShape(Rectangle())
                                            .padding(.vertical, 4)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        if showRepoDropdown {
                                            Divider()
                                                .background(ClaudeColors.border)
                                                .padding(.vertical, 6)
                                            
                                            ScrollView {
                                                VStack(spacing: 0) {
                                                    ForEach(repos) { repo in
                                                        Button(action: {
                                                            selectedRepo = repo
                                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                                showRepoDropdown = false
                                                            }
                                                        }) {
                                                            HStack {
                                                                Text(repo.fullName)
                                                                    .font(ClaudeTypography.bodyFont)
                                                                    .foregroundStyle(ClaudeColors.text)
                                                                    .lineLimit(1)
                                                                    .truncationMode(.tail)
                                                                Spacer()
                                                                if selectedRepo == repo {
                                                                    Image(systemName: "checkmark")
                                                                        .font(.system(size: 12, weight: .bold))
                                                                        .foregroundStyle(ClaudeColors.accent)
                                                                }
                                                            }
                                                            .padding(.vertical, 10)
                                                            .contentShape(Rectangle())
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                }
                                            }
                                            .frame(maxHeight: 240)
                                        }
                                    }
                                }
                                
                                if selectedRepo != nil {
                                    Divider()
                                        .background(ClaudeColors.border)
                                    
                                    if isLoadingBranches {
                                        HStack {
                                            ProgressView()
                                                .padding(.trailing, 8)
                                            Text("loading_branches".localized)
                                                .font(ClaudeTypography.bodyFont)
                                                .foregroundStyle(ClaudeColors.textSecondary)
                                        }
                                    } else if let error = branchErrorMessage {
                                        Text(error)
                                            .font(ClaudeTypography.captionFont)
                                            .foregroundStyle(ClaudeColors.accent)
                                    } else {
                                        // 分支选择（自定义下拉列表）
                                        VStack(spacing: 0) {
                                            Button(action: {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    showBranchDropdown.toggle()
                                                    showRepoDropdown = false
                                                }
                                            }) {
                                                HStack {
                                                    Text("select_branch".localized)
                                                        .font(ClaudeTypography.bodyFont)
                                                        .foregroundStyle(ClaudeColors.text)
                                                    Spacer()
                                                    Text(selectedBranch.isEmpty ? "please_select".localized : selectedBranch)
                                                        .font(ClaudeTypography.bodyFont)
                                                        .foregroundStyle(!selectedBranch.isEmpty ? ClaudeColors.link : ClaudeColors.textMuted)
                                                    Image(systemName: showBranchDropdown ? "chevron.up" : "chevron.down")
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(ClaudeColors.textMuted)
                                                }
                                                .contentShape(Rectangle())
                                                .padding(.vertical, 4)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            if showBranchDropdown {
                                                Divider()
                                                    .background(ClaudeColors.border)
                                                    .padding(.vertical, 6)
                                                
                                                ScrollView {
                                                    VStack(spacing: 0) {
                                                        ForEach(branches, id: \.self) { branchName in
                                                            Button(action: {
                                                                selectedBranch = branchName
                                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                                    showBranchDropdown = false
                                                                }
                                                            }) {
                                                                HStack {
                                                                    Text(branchName)
                                                                        .font(ClaudeTypography.bodyFont)
                                                                        .foregroundStyle(ClaudeColors.text)
                                                                    Spacer()
                                                                    if selectedBranch == branchName {
                                                                        Image(systemName: "checkmark")
                                                                            .font(.system(size: 12, weight: .bold))
                                                                            .foregroundStyle(ClaudeColors.accent)
                                                                    }
                                                                }
                                                                .padding(.vertical, 10)
                                                                .contentShape(Rectangle())
                                                            }
                                                            .buttonStyle(.plain)
                                                        }
                                                    }
                                                }
                                                .frame(maxHeight: 200)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    if let error = cloneErrorMessage {
                        Text(error)
                            .font(ClaudeTypography.captionFont)
                            .foregroundStyle(ClaudeColors.accent)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(20)
            }
            .background(ClaudeColors.background)
            .navigationTitle("add_repo_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
                        .font(ClaudeTypography.bodyFont)
                        .foregroundStyle(ClaudeColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: startClone) {
                        if isCloning {
                            ProgressView()
                        } else {
                            Text("clone".localized)
                                .font(ClaudeTypography.bodyFont.weight(.semibold))
                                .foregroundStyle(isFormValid ? ClaudeColors.accent : ClaudeColors.textMuted)
                        }
                    }
                    .disabled(!isFormValid || isCloning)
                }
            }
            .onChange(of: selectedAccountID) { _, _ in
                loadRepositories()
            }
            .onChange(of: selectedRepo) { _, _ in
                loadBranches()
            }
            .onAppear {
                // 默认选中侧边栏当前选中的账号（如果不是“全部”）
                if let sidebarAccountID = GitSyncService.shared.selectedSidebarAccountID {
                    self.selectedAccountID = sidebarAccountID
                } else {
                    self.selectedAccountID = nil
                }
                loadRepositories()
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
                    
                    // 获取真实用户名
                    let username = try await GitHubDeviceFlowService.shared.fetchUserInfo(token: token)
                    
                    // 授权成功，保存账号
                    let account = try AccountManager.shared.saveAccount(
                        username: username,
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
                    
                    // 获取真实用户名
                    let username = try await GitLabDeviceFlowService.shared.fetchUserInfo(token: token, serverURL: serverURL.isEmpty ? nil : serverURL)
                    
                    // 授权成功，保存账号
                    let account = try AccountManager.shared.saveAccount(
                        username: username,
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
    
    private func startTokenLogin() {
        loginErrorMessage = nil
        isVerifyingToken = true
        
        let token = inputToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let server = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                if selectedPlatform == .github {
                    // 验证 Token 并获取用户名
                    let username = try await GitHubDeviceFlowService.shared.fetchUserInfo(token: token)
                    
                    // 保存账号
                    let account = try AccountManager.shared.saveAccount(
                        username: username,
                        platform: .github,
                        token: token
                    )
                    
                    await MainActor.run {
                        self.selectedAccountID = account.id
                        self.showLoginSection = false
                        self.inputToken = ""
                        self.isVerifyingToken = false
                    }
                } else {
                    let serverURLParam = server.isEmpty ? nil : server
                    // 验证 Token 并获取用户名
                    let username = try await GitLabDeviceFlowService.shared.fetchUserInfo(token: token, serverURL: serverURLParam)
                    
                    // 保存账号
                    let account = try AccountManager.shared.saveAccount(
                        username: username,
                        platform: .gitlab,
                        token: token,
                        serverURL: serverURLParam
                    )
                    
                    await MainActor.run {
                        self.selectedAccountID = account.id
                        self.showLoginSection = false
                        self.inputToken = ""
                        self.isVerifyingToken = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.loginErrorMessage = error.localizedDescription
                    self.isVerifyingToken = false
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
    
    // MARK: - Repository & Branch Loading
    
    private func loadRepositories() {
        guard let accountID = selectedAccountID,
              let account = accountManager.accounts.first(where: { $0.id == accountID }),
              let token = accountManager.getToken(forAccountID: accountID) else {
            self.repos = []
            self.selectedRepo = nil
            self.branches = []
            self.selectedBranch = ""
            return
        }
        
        isLoadingRepos = true
        repoErrorMessage = nil
        self.repos = []
        self.selectedRepo = nil
        self.branches = []
        self.selectedBranch = ""
        
        Task {
            do {
                if account.platform == .github {
                    let githubRepos = try await GitHubDeviceFlowService.shared.fetchRepositories(token: token)
                    await MainActor.run {
                        self.repos = githubRepos.map { repo in
                            UnifiedRepo(
                                id: String(repo.id),
                                name: repo.name,
                                fullName: repo.fullName,
                                cloneURL: repo.cloneUrl,
                                isPrivate: repo.isPrivate
                            )
                        }
                        self.isLoadingRepos = false
                    }
                } else if account.platform == .gitlab {
                    let gitlabRepos = try await GitLabDeviceFlowService.shared.fetchRepositories(token: token, serverURL: account.serverURL)
                    await MainActor.run {
                        self.repos = gitlabRepos.map { repo in
                            UnifiedRepo(
                                id: String(repo.id),
                                name: repo.name,
                                fullName: repo.pathWithNamespace,
                                cloneURL: repo.httpUrlToRepo,
                                isPrivate: true
                            )
                        }
                        self.isLoadingRepos = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.repoErrorMessage = error.localizedDescription
                    self.isLoadingRepos = false
                }
            }
        }
    }
    
    private func loadBranches() {
        guard let accountID = selectedAccountID,
              let account = accountManager.accounts.first(where: { $0.id == accountID }),
              let token = accountManager.getToken(forAccountID: accountID),
              let repo = selectedRepo else {
            self.branches = []
            self.selectedBranch = ""
            return
        }
        
        isLoadingBranches = true
        branchErrorMessage = nil
        self.branches = []
        self.selectedBranch = ""
        
        Task {
            do {
                let branchNames: [String]
                if account.platform == .github {
                    let parts = repo.fullName.split(separator: "/")
                    guard parts.count == 2 else { throw URLError(.badURL) }
                    let owner = String(parts[0])
                    let repoName = String(parts[1])
                    branchNames = try await GitHubDeviceFlowService.shared.fetchBranches(token: token, owner: owner, repo: repoName)
                } else if account.platform == .gitlab {
                    guard let projectID = Int(repo.id) else { throw URLError(.badURL) }
                    branchNames = try await GitLabDeviceFlowService.shared.fetchBranches(token: token, serverURL: account.serverURL, projectID: projectID)
                } else {
                    branchNames = []
                }
                
                await MainActor.run {
                    self.branches = branchNames
                    if branchNames.contains("main") {
                        self.selectedBranch = "main"
                    } else if branchNames.contains("master") {
                        self.selectedBranch = "master"
                    } else {
                        self.selectedBranch = branchNames.first ?? ""
                    }
                    self.isLoadingBranches = false
                }
            } catch {
                await MainActor.run {
                    self.branchErrorMessage = error.localizedDescription
                    self.isLoadingBranches = false
                }
            }
        }
    }
    
    // MARK: - Clone Action
    
    private func startClone() {
        cloneErrorMessage = nil
        isCloning = true
        
        let finalURL: String
        let finalBranch: String
        
        if selectedAccountID == nil {
            finalURL = repoURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
            finalBranch = trimmedBranch.isEmpty ? "main" : trimmedBranch
        } else {
            guard let repo = selectedRepo else {
                cloneErrorMessage = "please_select".localized
                isCloning = false
                return
            }
            finalURL = repo.cloneURL
            finalBranch = selectedBranch
        }
        
        Task {
            do {
                try await syncService.clone(
                    repoURL: finalURL,
                    branch: finalBranch,
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
