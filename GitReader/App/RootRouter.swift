import SwiftUI

/// 根路由：根据是否已配置仓库决定启动页面
/// 若 Keychain 中有 PAT → 直接进入 FileListView
/// 否则 → 进入 RepoConfigView
struct RootRouter: View {
    @Binding var hasConfiguredRepo: Bool

    var body: some View {
        Group {
            if hasConfiguredRepo {
                FileListView(hasConfiguredRepo: $hasConfiguredRepo)
            } else {
                RepoConfigView(hasConfiguredRepo: $hasConfiguredRepo)
            }
        }
    }
}
