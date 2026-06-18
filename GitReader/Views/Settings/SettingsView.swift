import SwiftUI

/// 设置页
/// 显示仓库信息、同步触发、断开连接
struct SettingsView: View {
    @Binding var hasConfiguredRepo: Bool
    @StateObject private var localizationManager = LocalizationManager.shared

    @State private var showDisconnectAlert = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var isSyncing = false

    let repoURL: String
    let branch: String

    var body: some View {
        List {
            // 仓库信息
            Section {
                SettingsRow(
                    icon: "link",
                    label: "repo_address".localized,
                    value: repoURL
                )

                SettingsRow(
                    icon: "key.horizontal",
                    label: "pat_token".localized,
                    value: maskToken(KeychainService.shared.readToken() ?? "")
                )

                SettingsRow(
                    icon: "leaf",
                    label: "branch".localized,
                    value: branch
                )
            } header: {
                sectionHeader("repo_info".localized)
            }

            // 同步
            Section {
                Button(action: performSync) {
                    HStack(spacing: 12) {
                        if isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 16))
                                .foregroundStyle(ClaudeColors.textSecondary)
                        }

                        Text(isSyncing ? "syncing".localized : "sync_now".localized)
                            .font(ClaudeTypography.bodyFont)
                            .foregroundStyle(ClaudeColors.text)

                        Spacer()

                        Text("just_updated".localized)
                            .font(ClaudeTypography.codeCaptionFont)
                            .foregroundStyle(ClaudeColors.textMuted)
                    }
                    .padding(.vertical, 4)
                }
                .disabled(isSyncing)
            }

            // 属性模板管理
            Section {
                NavigationLink(destination: PropertyTemplateSettingsView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundStyle(ClaudeColors.textSecondary)
                        Text("property_template_management".localized)
                            .font(ClaudeTypography.bodyFont)
                            .foregroundStyle(ClaudeColors.text)
                    }
                    .padding(.vertical, 4)
                }
            }

            // 语言设置
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 16))
                        .foregroundStyle(ClaudeColors.textSecondary)
                        .frame(width: 22)
                    
                    Text("language".localized)
                        .font(ClaudeTypography.bodyFont)
                        .foregroundStyle(ClaudeColors.text)
                    
                    Spacer()
                    
                    Picker("", selection: $localizationManager.currentLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(ClaudeColors.textSecondary)
                }
                .padding(.vertical, 4)
            } header: {
                sectionHeader("language".localized)
            }

            // 关于
            Section {
                SettingsRow(
                    icon: "book.closed",
                    label: "git_reader".localized,
                    value: "v0.1.0 MVP"
                )

                Button(role: .destructive, action: { showDisconnectAlert = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                        Text("disconnect_repo".localized)
                            .font(ClaudeTypography.bodyFont)
                    }
                }
            } header: {
                sectionHeader("about".localized)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ClaudeColors.background)
        .navigationTitle("settings".localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert("disconnect_repo".localized, isPresented: $showDisconnectAlert) {
            Button("cancel".localized, role: .cancel) {}
            Button("disconnect".localized, role: .destructive) {
                disconnectRepository()
            }
        } message: {
            Text("disconnect_alert_message".localized)
        }
        .overlay(alignment: .bottom) {
            ToastView(message: toastMessage, isPresented: $showToast)
        }
    }

    // MARK: - Actions

    private func performSync() {
        isSyncing = true

        Task {
            do {
                try await GitSyncService.shared.sync()
                await MainActor.run {
                    isSyncing = false
                    toastMessage = "sync_completed".localized
                    showToast = true
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    toastMessage = "sync_failed".localized(arguments: error.localizedDescription)
                    showToast = true
                }
            }
        }
    }

    private func disconnectRepository() {
        GitSyncService.shared.reset()

        toastMessage = "disconnected_success".localized
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.4)) {
                hasConfiguredRepo = false
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(ClaudeTypography.monoCaptionFont)
            .foregroundStyle(ClaudeColors.textMuted)
            .tracking(0.8)
    }

    private func maskToken(_ token: String) -> String {
        guard token.count > 8 else { return "••••" }
        let prefix = String(token.prefix(4))
        let suffix = String(token.suffix(4))
        return "\(prefix)••••\(suffix)"
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(ClaudeColors.textSecondary)
                .frame(width: 22)

            Text(label)
                .font(ClaudeTypography.bodyFont)
                .foregroundStyle(ClaudeColors.text)

            Spacer()

            Text(value)
                .font(ClaudeTypography.codeCaptionFont)
                .foregroundStyle(ClaudeColors.textMuted)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(
            hasConfiguredRepo: .constant(true),
            repoURL: "github.com/user/my-second-brain",
            branch: "main"
        )
    }
}
