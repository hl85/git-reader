import SwiftUI

struct MainContainerView: View {
    @Binding var hasConfiguredRepo: Bool
    @StateObject private var syncService = GitSyncService.shared
    
    @State private var showAddRepoSheet = false
    @State private var showAccountManagementSheet = false
    @State private var showiPhoneSidebar = false
    @State private var selectedFile: FileItem?
    @State private var noteIndex: [String: URL] = [:]
    
    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad / macOS: 使用 NavigationSplitView 三栏布局
                NavigationSplitView {
                    // 第一栏：仓库切换侧边栏
                    SidebarView(
                        showAddRepoSheet: $showAddRepoSheet,
                        showAccountManagementSheet: $showAccountManagementSheet
                    )
                    .navigationSplitViewColumnWidth(80)
                    .toolbar(.hidden, for: .navigationBar)
                } content: {
                    // 第二栏：文件列表
                    NavigationStack {
                        FileListView(
                            hasConfiguredRepo: $hasConfiguredRepo,
                            selectedFile: $selectedFile,
                            noteIndex: $noteIndex
                        )
                    }
                    .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
                } detail: {
                    // 第三栏：内容阅读区（NavigationSplitView 已提供导航上下文）
                    NavigationStack {
                        if let file = selectedFile {
                            NoteReaderView(
                                fileURL: file.url,
                                noteIndex: noteIndex
                            )
                            .id(file.id)
                        } else {
                            DetailPlaceholderView()
                        }
                    }
                }
            } else {
                // iPhone: 使用双栏或抽屉布局
                ZStack(alignment: .leading) {
                    // 主内容区
                    NavigationStack {
                        FileListView(
                            hasConfiguredRepo: $hasConfiguredRepo,
                            selectedFile: $selectedFile,
                            noteIndex: $noteIndex
                        )
                        .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            showiPhoneSidebar.toggle()
                                        }
                                    }) {
                                        Image(systemName: "sidebar.left")
                                            .foregroundStyle(ClaudeColors.textSecondary)
                                    }
                                }
                            }
                    }
                    
                    // 抽屉侧边栏
                    if showiPhoneSidebar {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showiPhoneSidebar = false
                                }
                            }
                        
                        SidebarView(
                            showAddRepoSheet: $showAddRepoSheet,
                            showAccountManagementSheet: $showAccountManagementSheet
                        )
                        .frame(width: 80)
                        .background(ClaudeColors.cardBackground)
                        .contentShape(Rectangle())
                        .transition(.move(edge: .leading))
                        .ignoresSafeArea(edges: .bottom)
                        .zIndex(1)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddRepoSheet) {
            AddRepositoryView()
        }
        .sheet(isPresented: $showAccountManagementSheet) {
            AccountManagementView()
        }
        .onChange(of: syncService.activeRepositoryID) { _, _ in
            // 切换仓库时，自动收起 iPhone 侧边栏
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showiPhoneSidebar = false
            }
        }
    }
}

struct DetailPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("📝")
                .font(.system(size: 64))
            Text("select_note_to_read".localized)
                .font(.headline)
                .foregroundStyle(ClaudeColors.textSecondary)
            Text("select_note_to_read_desc".localized)
                .font(.subheadline)
                .foregroundStyle(ClaudeColors.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ClaudeColors.background)
    }
}
