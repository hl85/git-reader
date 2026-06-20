import SwiftUI

struct SidebarView: View {
    @StateObject private var syncService = GitSyncService.shared
    @Binding var showAddRepoSheet: Bool
    @Binding var showAccountManagementSheet: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // 账号管理入口
            Button(action: { showAccountManagementSheet = true }) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 24))
                    .foregroundStyle(ClaudeColors.textSecondary)
            }
            .padding(.top, 16)
            .buttonStyle(.plain)
            
            Divider()
                .padding(.horizontal, 12)
            
            // 仓库列表
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(syncService.repositories) { repo in
                        let isSelected = repo.id == syncService.activeRepositoryID
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                syncService.activeRepositoryID = repo.id
                            }
                        }) {
                            Text(String(repo.name.prefix(1)).uppercased())
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(isSelected ? .white : ClaudeColors.textSecondary)
                                .frame(width: 48, height: 44)
                                .background(isSelected ? ClaudeColors.accent : ClaudeColors.tagBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive, action: {
                                syncService.activeRepositoryID = repo.id
                                syncService.reset()
                            }) {
                                Label("delete_repo".localized, systemImage: "trash")
                            }
                        }
                    }
                    
                    // 新增仓库按钮
                    Button(action: { showAddRepoSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(ClaudeColors.textSecondary)
                            .frame(width: 48, height: 44)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ClaudeColors.border, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4]))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(ClaudeColors.cardBackground)
    }
}
