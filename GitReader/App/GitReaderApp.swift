import SwiftUI

@main
struct GitReaderApp: App {
    @State private var hasConfiguredRepo: Bool = false

    var body: some Scene {
        WindowGroup {
            SplashWrapperView {
                AppRootView(hasConfiguredRepo: $hasConfiguredRepo)
            }
        }
    }
}

/// 内层 View：访问 Environment 并在 ScenePhase 变化时触发同步
struct AppRootView: View {
    @Binding var hasConfiguredRepo: Bool
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        RootRouter(hasConfiguredRepo: $hasConfiguredRepo)
            .onAppear {
                hasConfiguredRepo = GitSyncService.shared.isConfigured
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active,
                   hasConfiguredRepo,
                   NetworkMonitor.shared.isConnected {
                    Task {
                        try? await GitSyncService.shared.sync()
                    }
                }
            }
    }
}
