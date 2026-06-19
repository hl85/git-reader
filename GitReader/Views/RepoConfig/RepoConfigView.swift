import SwiftUI

/// 仓库配置页：首次使用时输入 Git URL + PAT
struct RepoConfigView: View {
    @Binding var hasConfiguredRepo: Bool
    @StateObject private var localizationManager = LocalizationManager.shared

    @State private var repoURL = ""
    @State private var patToken = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var showToast = false
    @State private var toastMessage = ""

    private var isFormValid: Bool {
        !repoURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !patToken.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo + 标题
                    headerSection

                    // 表单
                    formSection

                    // 安全声明
                    footerSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
            }
            .background(ClaudeColors.background)
            .scrollDismissesKeyboard(.immediately)
            .overlay(alignment: .bottom) {
                ToastView(message: toastMessage, isPresented: $showToast)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 24) {
            // Vector Logo (Static version of Splash Logo)
            ZStack {
                // Left Page
                LeftPageShape()
                    .stroke(ClaudeColors.text, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                
                // Right Page
                RightPageShape()
                    .stroke(ClaudeColors.text, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                
                // Spine (Git Branch Line)
                GeometryReader { geo in
                    Path { path in
                        path.move(to: CGPoint(x: geo.size.width / 2, y: 10 * (geo.size.height / 100)))
                        path.addLine(to: CGPoint(x: geo.size.width / 2, y: 90 * (geo.size.height / 100)))
                    }
                    .stroke(ClaudeColors.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
                
                // Top Node
                Circle()
                    .fill(ClaudeColors.accent)
                    .frame(width: 8, height: 8)
                    .position(x: 60, y: 30)
                
                // Bottom Node
                Circle()
                    .fill(ClaudeColors.accent)
                    .frame(width: 8, height: 8)
                    .position(x: 60, y: 90)
            }
            .frame(width: 120, height: 120)

            VStack(spacing: 8) {
                Text("Gits Reader")
                    .font(.custom("Georgia", size: 30))
                    .fontWeight(.medium)
                    .foregroundColor(ClaudeColors.text)

                Text("YOUR OBSIDIAN VAULT")
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .tracking(1.5)
                    .foregroundColor(ClaudeColors.textSecondary)
            }
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 20) {
            // 仓库地址
            VStack(alignment: .leading, spacing: 8) {
                label("repo_address".localized)
                TextField(
                    "https://github.com/user/notes.git",
                    text: $repoURL
                )
                .font(ClaudeTypography.codeCaptionFont)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(ClaudeColors.background)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ClaudeColors.border, lineWidth: 1)
                )
            }

            // PAT Token
            VStack(alignment: .leading, spacing: 8) {
                label("pat_token".localized)
                SecureField(
                    "ghp_xxxxxxxxxxxxxxxxxxxx",
                    text: $patToken
                )
                .font(ClaudeTypography.codeCaptionFont)
                .textContentType(.password)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(ClaudeColors.background)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ClaudeColors.border, lineWidth: 1)
                )
            }

            // 错误提示
            if let error = errorMessage {
                Text(error)
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(ClaudeColors.accent)
                    .transition(.opacity)
            }

            // 提交按钮
            Button(action: connectRepository) {
                Group {
                    if isConnecting {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("connecting".localized)
                        }
                    } else {
                        Text("connect_repo".localized)
                    }
                }
                .font(ClaudeTypography.bodyFont.weight(.semibold))
                .foregroundStyle(ClaudeColors.background)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(ClaudeColors.text)
                .cornerRadius(10)
            }
            .disabled(!isFormValid || isConnecting)
            .opacity((!isFormValid || isConnecting) ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFormValid)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        Text("security_notice".localized)
            .font(.system(.footnote, design: .serif))
            .foregroundStyle(ClaudeColors.textMuted)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.top, 8)
    }

    // MARK: - Actions

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(ClaudeTypography.monoCaptionFont.weight(.medium))
            .foregroundStyle(ClaudeColors.textSecondary)
            .tracking(0.8)
    }

    private func connectRepository() {
        errorMessage = nil
        isConnecting = true

        let trimmedURL = repoURL.trimmingCharacters(in: .whitespaces)
        let trimmedToken = patToken.trimmingCharacters(in: .whitespaces)

        // 仅进行 HTTP Session 级别的连接测试
        Task {
            do {
                try await GitSyncService.shared.testConnection(repoURL: trimmedURL, token: trimmedToken)
                
                // 测试成功后，保存 Token 到 Keychain
                try KeychainService.shared.saveToken(trimmedToken)
                
                // 持久化仓库配置信息
                GitSyncService.shared.repoURL = trimmedURL
                GitSyncService.shared.branch = "main" // 默认使用 main 分支
                
                await MainActor.run {
                    isConnecting = false
                    toastMessage = "repo_connected_success".localized
                    showToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            hasConfiguredRepo = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "connection_failed_with_error".localized(arguments: error.localizedDescription)
                    isConnecting = false
                }
            }
        }
    }
}

#Preview {
    RepoConfigView(hasConfiguredRepo: .constant(false))
}
