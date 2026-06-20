# OAuth 登录与多仓库管理功能实施计划 (Plan)

* **日期**：2026-06-20
* **关联设计文档**：[2026-06-20-oauth-and-multi-repo-design.md](file:///Users/wanghui/Code/git-reader/docs/superpowers/specs/2026-06-20-oauth-and-multi-repo-design.md)

为了稳妥、高效地实现该功能，我们将整个实施过程分为 **5 个阶段**。每个阶段都包含明确的开发任务和验证步骤，确保代码质量与系统稳定性。

---

## 📅 阶段划分与任务列表

### 阶段 1：基础数据模型与存储重构 (基础建设)
本阶段重点重构本地存储结构，建立多仓库和多账号的数据模型，并实现沙盒目录隔离。

* [ ] **任务 1.1：定义核心数据模型**
  * 在 `GitReader/Models/` 下创建 `GitModels.swift`。
  * 定义 `GitPlatform` 枚举、`AccountInfo` 结构体和 `RepositoryInfo` 结构体（均实现 `Codable` 和 `Identifiable`）。
* [ ] **任务 1.2：重构 KeychainService**
  * 修改 `KeychainService`，支持传入 `accountID` (UUID 字符串) 作为 `kSecAttrAccount`，实现多账号 Token 隔离存储。
  * 保留向后兼容性（若未传入 `accountID`，默认使用原有的 `"personal-access-token"` 账户）。
* [ ] **任务 1.3：重构 GitSyncService 存储逻辑**
  * 废弃原有的单仓库 `UserDefaults` 键（`repoURL`、`repoBranch`）。
  * 在 `GitSyncService` 中引入 `repositories: [RepositoryInfo]` 和 `activeRepositoryID: UUID?`。
  * 重构 `repoRootURL` 属性，使其动态指向 `Documents/repositories/\(activeRepositoryID)/`。
  * 实现沙盒目录自动创建与清理逻辑。

---

### 阶段 2：OAuth 设备流 (Device Flow) 认证实现
本阶段实现 GitHub 和 GitLab 的设备流认证逻辑，包括请求设备码、轮询 Token 以及安全存储。

* [ ] **任务 2.1：实现 GitHubDeviceFlowService**
  * 创建 `GitHubDeviceFlowService`，负责与 GitHub 设备流 API 交互：
    1. `requestDeviceCode()` -> 获取 `user_code`、`verification_uri` 等。
    2. `pollForToken(deviceCode:interval:)` -> 轮询获取 `access_token`。
* [ ] **任务 2.2：实现 GitLabDeviceFlowService**
  * 创建 `GitLabDeviceFlowService`，支持官方云端（gitlab.com）和自定义私有部署域名。
  * 实现与 GitLab 设备流 API 的交互与轮询。
* [ ] **任务 2.3：集成到账号管理器 (AccountManager)**
  * 创建 `AccountManager`，统一管理已登录的 `AccountInfo` 列表。
  * 登录成功后，自动创建 `AccountInfo` 存入 `UserDefaults`，并将 Token 写入 `Keychain`。

---

### 阶段 3：多仓库管理与克隆同步适配
本阶段适配 `GitSyncService` 的底层 Git 操作，使其支持多仓库的独立克隆、拉取和推送。

* [ ] **任务 3.1：适配 GitSyncService 的克隆与同步 API**
  * 修改 `clone(repoURL:branch:accountID:)`，使其在对应的隔离目录下执行克隆。
  * 修改 `sync()` 和 `commitAndSync()`，动态获取当前激活仓库关联的账号 Token，并传入 `SwiftLibgit2`。
* [ ] **任务 3.2：适配 FileScannerService**
  * 修改 `FileScannerService`，使其扫描根路径动态绑定到当前激活仓库的隔离目录。
  * 当 `activeRepositoryID` 切换时，自动重置扫描器并重新扫描文件。

---

### 阶段 4：iPad 侧边栏 (Sidebar) 与多仓库 UI 开发
本阶段开发全新的多仓库管理界面，包括 iPad 侧边栏、iPhone 抽屉视图以及账号/仓库管理弹窗。

* [ ] **任务 4.1：开发 SidebarView (仓库切换侧边栏)**
  * 采用 `NavigationSplitView` 实现三栏布局。
  * 最左侧开发垂直的仓库图标列表，支持点击切换、长按删除/编辑。
  * 底部提供 `+` 按钮。
* [ ] **任务 4.2：开发 AddRepositoryView (新增仓库弹窗)**
  * 提供输入 Git URL、选择分支的表单。
  * 提供“关联账号”下拉菜单，展示已登录账号，并提供“添加新账号”入口。
* [ ] **任务 4.3：开发 AccountManagementView (账号管理界面)**
  * 在设置页中，提供已登录账号列表，支持解绑/退出登录。

---

### 阶段 5：系统集成、测试与抛光 (Testing & Polish)
本阶段进行全面的功能集成测试、边界情况处理和 UI 细节抛光。

* [ ] **任务 5.1：编写单元测试**
  * 在 `TestPackage` 中，针对 `AccountInfo`、`RepositoryInfo` 的持久化进行测试。
  * 测试 `KeychainService` 的多账号隔离读写。
* [ ] **任务 5.2：边界情况处理**
  * 处理网络中断时的轮询重试与超时。
  * 处理本地沙盒目录创建失败、磁盘空间不足等异常。
  * 处理 Token 失效时的重新授权提示。
* [ ] **任务 5.3：UI 细节抛光**
  * 为侧边栏切换添加流畅的过渡动画。
  * 适配深色模式 (Dark Mode) 和 iPad 各种分屏尺寸。

---

## 🧪 验证方法 (Verification)

1. **数据隔离验证**：
   * 关联两个不同的 Git 仓库，在沙盒中检查 `Documents/repositories/` 下是否生成了两个不同的 UUID 目录，且各自包含独立的 `.git` 和笔记文件。
2. **安全隔离验证**：
   * 登录两个不同的 GitHub 账号，检查 Keychain 中是否安全存储了两个不同的 Token，且 Account 键分别为各自的 Account UUID。
3. **设备流验证**：
   * 模拟完整的登录流程，确保验证码展示正确，点击“复制并打开”能正确跳转，且在浏览器授权后 App 能在 3 秒内自动完成登录。
4. **iPad 适配验证**：
   * 在 iPad 模拟器上运行，测试 Split View 分屏、Slide Over 悬浮窗下的侧边栏展示与交互是否完美。
