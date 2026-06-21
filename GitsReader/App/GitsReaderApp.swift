import SwiftUI
import BackgroundTasks

@main
struct GitsReaderApp: App {
    @State private var hasConfiguredRepo: Bool = false
    @AppStorage("appTheme") private var appTheme: String = AppTheme.system.rawValue

    init() {
        registerBackgroundSync()
    }

    var body: some Scene {
        WindowGroup {
            SplashWrapperView {
                AppRootView(hasConfiguredRepo: $hasConfiguredRepo)
            }
            .preferredColorScheme(AppTheme(rawValue: appTheme)?.colorScheme)
        }
    }

    private func registerBackgroundSync() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.holooapp.gitsreader.background_sync",
            using: nil
        ) { task in
            handleBackgroundSync(task: task as! BGAppRefreshTask)
        }
    }

    private func handleBackgroundSync(task: BGAppRefreshTask) {
        // 1. 立即调度下一次后台同步，形成循环
        scheduleBackgroundSync()

        // 2. 设置超时回调
        task.expirationHandler = {
            print("[BackgroundSync] Task expired and cancelled")
        }

        // 3. 执行同步
        Task {
            do {
                if NetworkMonitor.shared.isConnected, GitSyncService.shared.isConfigured {
                    print("[BackgroundSync] Starting background sync...")
                    try await GitSyncService.shared.sync()
                    task.setTaskCompleted(success: true)
                    print("[BackgroundSync] Background sync completed successfully")
                } else {
                    task.setTaskCompleted(success: false)
                    print("[BackgroundSync] Background sync skipped: no network or repo not configured")
                }
            } catch {
                task.setTaskCompleted(success: false)
                print("[BackgroundSync] Background sync failed: \(error.localizedDescription)")
            }
        }
    }
}

/// 调度下一次后台同步
func scheduleBackgroundSync() {
    let request = BGAppRefreshTaskRequest(identifier: "com.holooapp.gitsreader.background_sync")
    // 建议至少 15 分钟后触发（iOS 系统会根据用户使用习惯动态调度）
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    
    do {
        try BGTaskScheduler.shared.submit(request)
        print("[BackgroundSync] Scheduled next sync successfully")
    } catch {
        print("[BackgroundSync] Failed to schedule background sync: \(error)")
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
                switch newPhase {
                case .active:
                    if hasConfiguredRepo, NetworkMonitor.shared.isConnected {
                        Task {
                            try? await GitSyncService.shared.sync()
                        }
                    }
                case .background:
                    if hasConfiguredRepo {
                        scheduleBackgroundSync()
                    }
                default:
                    break
                }
            }
    }
}
