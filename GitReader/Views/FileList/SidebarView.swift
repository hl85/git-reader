import SwiftUI

struct SidebarView: View {
    @StateObject private var syncService = GitSyncService.shared
    @StateObject private var accountManager = AccountManager.shared
    @Binding var showAddRepoSheet: Bool
    @Binding var showAccountManagementSheet: Bool
    
    @State private var isAccountsExpanded = false
    
    private let publicAccountID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    
    private var filteredRepositories: [RepositoryInfo] {
        if syncService.selectedSidebarAccountID == nil {
            return syncService.repositories
        } else if syncService.selectedSidebarAccountID == publicAccountID {
            return syncService.repositories.filter { $0.accountID == nil }
        } else {
            return syncService.repositories.filter { $0.accountID == syncService.selectedSidebarAccountID }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 账号切换与管理入口（展开/折叠模式）
            VStack(spacing: 8) {
                if !isAccountsExpanded {
                    // 折叠状态：只显示当前选中的账户/过滤器
                    collapsedAccountTile
                } else {
                    // 展开状态：显示所有选项
                    expandedAccountTiles
                }
            }
            .padding(.top, 16)
            
            Divider()
                .padding(.horizontal, 12)
            
            // 仓库列表
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(filteredRepositories) { repo in
                        sidebarTile(
                            text: String(repo.name.prefix(1)).uppercased(),
                            isSelected: repo.id == syncService.activeRepositoryID,
                            helpText: repo.name
                        ) {
                            print("[SidebarView] Clicked repository button: \(repo.name) (ID: \(repo.id))")
                            syncService.setActiveRepository(repo.id)
                        }
                        .contextMenu {
                            Button(role: .destructive, action: {
                                print("[SidebarView] Clicked delete repository button: \(repo.name) (ID: \(repo.id))")
                                syncService.setActiveRepository(repo.id)
                                syncService.reset()
                            }) {
                                Label("delete_repo".localized, systemImage: "trash")
                            }
                        }
                    }
                    
                    // 新增仓库按钮（虚线样式）
                    sidebarTile(
                        icon: "plus",
                        isDashed: true,
                        helpText: "add_repo_title".localized
                    ) {
                        print("[SidebarView] Clicked add repository button")
                        showAddRepoSheet = true
                    }
                }
                .padding(.horizontal, 12)
            }
            
            Spacer()
        }
        .frame(width: 80)
        .background(ClaudeColors.cardBackground)
    }
    
    // MARK: - Account Section (Collapsed)
    
    /// 折叠状态：显示当前选中的账户/过滤器，点击展开
    @ViewBuilder
    private var collapsedAccountTile: some View {
        if syncService.selectedSidebarAccountID == nil {
            sidebarTile(
                icon: "square.grid.2x2",
                showChevron: true,
                helpText: "all_repos".localized
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAccountsExpanded = true
                }
            }
        } else if syncService.selectedSidebarAccountID == publicAccountID {
            sidebarTile(
                icon: "globe",
                showChevron: true,
                helpText: "public_repo_no_auth".localized
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAccountsExpanded = true
                }
            }
        } else if let account = accountManager.accounts.first(where: { $0.id == syncService.selectedSidebarAccountID }) {
            sidebarTile(
                text: String(account.username.prefix(1)).uppercased(),
                showChevron: true,
                helpText: account.username
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAccountsExpanded = true
                }
            }
        } else {
            sidebarTile(
                icon: "square.grid.2x2",
                showChevron: true,
                helpText: "all_repos".localized
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAccountsExpanded = true
                }
            }
        }
    }
    
    // MARK: - Account Section (Expanded)
    
    /// 展开状态：显示所有账户选项 + 账户管理按钮
    @ViewBuilder
    private var expandedAccountTiles: some View {
        sidebarTile(
            icon: "square.grid.2x2",
            isSelected: syncService.selectedSidebarAccountID == nil,
            helpText: "all_repos".localized
        ) {
            print("[SidebarView] Account filter changed to: ALL")
            syncService.selectedSidebarAccountID = nil
            withAnimation(.easeInOut(duration: 0.2)) {
                isAccountsExpanded = false
            }
        }
        
        sidebarTile(
            icon: "globe",
            isSelected: syncService.selectedSidebarAccountID == publicAccountID,
            helpText: "public_repo_no_auth".localized
        ) {
            print("[SidebarView] Account filter changed to: PUBLIC")
            syncService.selectedSidebarAccountID = publicAccountID
            withAnimation(.easeInOut(duration: 0.2)) {
                isAccountsExpanded = false
            }
        }
        
        ForEach(accountManager.accounts) { account in
            sidebarTile(
                text: String(account.username.prefix(1)).uppercased(),
                isSelected: syncService.selectedSidebarAccountID == account.id,
                helpText: account.username
            ) {
                print("[SidebarView] Account filter changed to: \(account.username)")
                syncService.selectedSidebarAccountID = account.id
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAccountsExpanded = false
                }
            }
        }
        
        // 账户管理按钮（虚线样式）
        sidebarTile(
            icon: "person.badge.key",
            isDashed: true,
            helpText: "account_management_title".localized
        ) {
            print("[SidebarView] Clicked account management button")
            withAnimation(.easeInOut(duration: 0.2)) {
                isAccountsExpanded = false
            }
            showAccountManagementSheet = true
        }
    }
    
    // MARK: - Unified Sidebar Tile
    
    /// 统一的侧边栏方块按钮，账户/仓库/管理/新增共用同一模板
    @ViewBuilder
    private func sidebarTile(
        icon: String? = nil,
        text: String? = nil,
        isSelected: Bool = false,
        isDashed: Bool = false,
        showChevron: Bool = false,
        helpText: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .center) {
                // 主内容（图标或文字）
                Group {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                    } else if let text = text {
                        Text(text)
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                
                // 右下角的小箭头（折叠状态提示可展开）
                if showChevron {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : ClaudeColors.textSecondary)
                                .padding(.trailing, 4)
                                .padding(.bottom, 4)
                        }
                    }
                }
            }
            .frame(width: 48, height: 44)
            .background(isDashed ? Color.clear : (isSelected ? ClaudeColors.accent : ClaudeColors.tagBackground))
            .foregroundStyle(isDashed ? ClaudeColors.textSecondary : (isSelected ? .white : ClaudeColors.textSecondary))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isDashed ? ClaudeColors.border : (isSelected ? Color.white : Color.clear),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: isDashed ? [4, 4] : [])
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(helpText)
    }
}
