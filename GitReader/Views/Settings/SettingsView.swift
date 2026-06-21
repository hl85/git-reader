import SwiftUI

/// 设置页
/// 显示仓库信息、同步触发、断开连接
struct SettingsView: View {
    @Binding var hasConfiguredRepo: Bool
    @Environment(\.dismiss) private var dismiss
    @StateObject private var localizationManager = LocalizationManager.shared
    @AppStorage("appTheme") private var appTheme: String = AppTheme.system.rawValue

    @State private var showDisconnectAlert = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var isSyncing = false
    @State private var showAccountManagement = false
    @State private var showAddRepo = false

    @ObservedObject private var syncService = GitSyncService.shared

    var body: some View {
        List {
            // 账号管理
            Section {
                Button(action: { showAccountManagement = true }) {
                    HStack {
                        Image(systemName: "person.badge.key")
                            .font(.system(size: 16))
                            .foregroundStyle(ClaudeColors.textSecondary)
                            .frame(width: 22)
                        
                        Text("account_management_title".localized)
                            .font(ClaudeTypography.bodyFont)
                            .foregroundStyle(ClaudeColors.text)
                        
                        Spacer()
                        
                        Text("\(AccountManager.shared.accounts.count) \("accounts_count".localized)")
                            .font(ClaudeTypography.captionFont)
                            .foregroundStyle(ClaudeColors.textMuted)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(ClaudeColors.textMuted)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            } header: {
                sectionHeader("auth_account".localized)
            }

            // 所有仓库管理
            Section {
                ForEach(syncService.repositories) { repo in
                    let isSelected = repo.id == syncService.activeRepositoryID
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(repo.name)
                                .font(ClaudeTypography.bodyFont.weight(isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? ClaudeColors.accent : ClaudeColors.text)
                            
                            Text("\(repo.url) (\(repo.branch))")
                                .font(ClaudeTypography.captionFont)
                                .foregroundStyle(ClaudeColors.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(ClaudeColors.accent)
                        } else {
                            Button(action: {
                                withAnimation {
                                    syncService.setActiveRepository(repo.id)
                                }
                            }) {
                                Text("switch".localized)
                                    .font(.subheadline)
                                    .foregroundStyle(ClaudeColors.link)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                     let repos = syncService.repositories
                     for index in indexSet {
                         let repo = repos[index]
                         if repo.id == syncService.activeRepositoryID {
                             syncService.reset()
                         } else {
                             var list = syncService.repositories
                             list.remove(at: index)
                             syncService.setRepositories(list)
                             let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                                 .appendingPathComponent("repositories")
                                 .appendingPathComponent(repo.id.uuidString)
                             try? FileManager.default.removeItem(at: base)
                         }
                     }
                 }
                 
                 // 添加仓库按钮
                 Button(action: { showAddRepo = true }) {
                     HStack(spacing: 12) {
                         Image(systemName: "plus.circle")
                             .font(.system(size: 16))
                             .foregroundStyle(ClaudeColors.accent)
                             .frame(width: 22)
                         
                         Text("add_repo_title".localized)
                             .font(ClaudeTypography.bodyFont)
                             .foregroundStyle(ClaudeColors.accent)
                     }
                     .padding(.vertical, 4)
                 }
                 .buttonStyle(.plain)
            } header: {
                sectionHeader("all_repos".localized)
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

            // 主题设置
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 16))
                        .foregroundStyle(ClaudeColors.textSecondary)
                        .frame(width: 22)
                    
                    Text("theme".localized)
                        .font(ClaudeTypography.bodyFont)
                        .foregroundStyle(ClaudeColors.text)
                    
                    Spacer()
                    
                    Picker("", selection: $appTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(ClaudeColors.textSecondary)
                }
                .padding(.vertical, 4)
            } header: {
                sectionHeader("theme".localized)
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
                    value: appVersionString
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("done".localized) {
                    dismiss()
                }
                .font(ClaudeTypography.bodyFont.weight(.semibold))
                .foregroundStyle(ClaudeColors.text)
            }
        }
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
        .sheet(isPresented: $showAccountManagement) {
             AccountManagementView()
         }
         .sheet(isPresented: $showAddRepo) {
             AddRepositoryView()
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

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

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
            hasConfiguredRepo: .constant(true)
        )
    }
}
