import SwiftUI

/// 仓库配置页：首次使用时的欢迎与初始化页面
struct RepoConfigView: View {
    @Binding var hasConfiguredRepo: Bool
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var syncService = GitSyncService.shared
    
    @State private var showAddRepoSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 40) {
                        // Logo + 标题
                        headerSection
                        
                        // 功能特性介绍
                        featuresSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                    .padding(.bottom, 24)
                }
                
                // 底部操作区
                VStack(spacing: 16) {
                    // 开始使用按钮
                    Button(action: { showAddRepoSheet = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.headline)
                            Text("add_first_repo".localized)
                                .font(ClaudeTypography.bodyFont.weight(.semibold))
                        }
                        .foregroundStyle(ClaudeColors.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(ClaudeColors.text)
                        .cornerRadius(12)
                    }
                    
                    // 安全声明
                    footerSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .background(ClaudeColors.background)
            }
            .background(ClaudeColors.background)
            .sheet(isPresented: $showAddRepoSheet) {
                AddRepositoryView()
                    .onDisappear {
                        // 当弹窗消失时，如果已经成功配置了仓库，则切换到主界面
                        if syncService.isConfigured {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                hasConfiguredRepo = true
                            }
                        }
                    }
            }
            .onChange(of: syncService.isConfigured) { _, isConfigured in
                if isConfigured {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        hasConfiguredRepo = true
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 24) {
            // App Icon Logo
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

            VStack(spacing: 8) {
                Text("Gits Reader")
                    .font(.custom("Georgia", size: 32))
                    .fontWeight(.medium)
                    .foregroundColor(ClaudeColors.text)

                Text("welcome_to_gits_reader".localized.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .tracking(1.5)
                    .foregroundColor(ClaudeColors.accent)
            }
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 24) {
            featureRow(
                icon: "folder.badge.plus",
                title: "welcome_feature_multi_repo".localized,
                description: "welcome_feature_multi_repo_desc".localized
            )
            
            featureRow(
                icon: "key.fill",
                title: "welcome_feature_oauth".localized,
                description: "welcome_feature_oauth_desc".localized
            )
            
            featureRow(
                icon: "wifi.slash",
                title: "welcome_feature_offline".localized,
                description: "welcome_feature_offline_desc".localized
            )
            
            featureRow(
                icon: "lock.shield.fill",
                title: "welcome_feature_secure".localized,
                description: "welcome_feature_secure_desc".localized
            )
        }
        .padding(.vertical, 8)
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(ClaudeColors.accent)
                .frame(width: 32, height: 32)
                .background(ClaudeColors.tagBackground)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ClaudeTypography.bodyFont.weight(.semibold))
                    .foregroundStyle(ClaudeColors.text)
                
                Text(description)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(ClaudeColors.textSecondary)
                    .lineSpacing(4)
            }
            
            Spacer()
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        Text("security_notice".localized)
            .font(.system(.footnote, design: .serif))
            .foregroundStyle(ClaudeColors.textMuted)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
    }
}

#Preview {
    RepoConfigView(hasConfiguredRepo: .constant(false))
}
