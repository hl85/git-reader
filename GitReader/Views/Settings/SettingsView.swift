import SwiftUI

/// 设置页
/// 显示仓库信息、同步触发、断开连接
struct SettingsView: View {
    @Binding var hasConfiguredRepo: Bool

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
                    label: "仓库地址",
                    value: repoURL
                )

                SettingsRow(
                    icon: "key.horizontal",
                    label: "Access Token",
                    value: maskToken(KeychainService.shared.readToken() ?? "")
                )

                SettingsRow(
                    icon: "leaf",
                    label: "分支",
                    value: branch
                )
            } header: {
                sectionHeader("仓库信息")
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

                        Text(isSyncing ? "正在同步..." : "立即同步")
                            .font(ClaudeTypography.bodyFont)
                            .foregroundStyle(ClaudeColors.text)

                        Spacer()

                        Text("刚刚更新")
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
                        Text("属性模板管理")
                            .font(ClaudeTypography.bodyFont)
                            .foregroundStyle(ClaudeColors.text)
                    }
                    .padding(.vertical, 4)
                }
            }

            // 关于
            Section {
                SettingsRow(
                    icon: "book.closed",
                    label: "Git Reader",
                    value: "v0.1.0 MVP"
                )

                Button(role: .destructive, action: { showDisconnectAlert = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                        Text("断开仓库连接")
                            .font(ClaudeTypography.bodyFont)
                    }
                }
            } header: {
                sectionHeader("关于")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ClaudeColors.background)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .alert("断开仓库连接", isPresented: $showDisconnectAlert) {
            Button("取消", role: .cancel) {}
            Button("断开", role: .destructive) {
                disconnectRepository()
            }
        } message: {
            Text("这将清除本地缓存和保存的 Token。")
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
                    toastMessage = "同步完成"
                    showToast = true
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    toastMessage = "同步失败: \(error.localizedDescription)"
                    showToast = true
                }
            }
        }
    }

    private func disconnectRepository() {
        GitSyncService.shared.reset()

        toastMessage = "已断开仓库连接"
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
