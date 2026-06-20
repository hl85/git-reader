# OAuth 登录与多仓库管理功能设计文档 (Spec)

* **设计日期**：2026-06-20
* **状态**：草案 (Draft)
* **作者**：GitReader AI Agent

---

## 1. 背景与目标 (Background & Goals)

目前，GitReader 仅支持通过手动输入 Git URL 和 Personal Access Token (PAT) 关联**单个**云端仓库。为了提升用户体验，并满足用户在多个 Obsidian 库之间无缝切换的需求，本项目计划引入：
1. **OAuth 登录 (GitHub / GitLab)**：通过安全的设备流 (Device Flow) 登录，自动获取 Token 并拉取用户仓库列表。
2. **多仓库管理**：支持在本地沙盒中隔离存储多个 Git 仓库，并通过 iPad 兼容的侧边栏 (Sidebar) 快速切换。

---

## 2. 核心设计决策 (Core Decisions)

| 维度 | 决策方案 | 决策原因 |
|------|----------|----------|
| **OAuth 认证方式** | **设备流 (Device Flow)** | 100% 纯客户端实现，无需中转服务器，无 Client Secret 泄露风险，安全可靠。 |
| **GitLab 兼容性** | **官方云端 + 私有部署 (Self-Hosted)** | 完美覆盖企业、高校等内网使用私有 GitLab 实例的专业用户。 |
| **多仓库管理 UI** | **侧边栏/抽屉视图 (Sidebar/Drawer)** | 切换高效，视觉直观，完美适配 iPad 大屏分栏布局 (NavigationSplitView)。 |
| **Token 共享机制** | **按账号/平台共享 Token** | 允许一个账号关联多个仓库，避免重复授权，用户体验极佳。 |
| **本地存储隔离** | **UUID 目录隔离** | 每个仓库分配独立的 UUID 目录，确保多仓库本地数据互不干扰。 |

---

## 3. 数据模型设计 (Data Models)

### 3.1 平台枚举 (GitPlatform)
```swift
enum GitPlatform: String, Codable {
    case github
    case gitlab
    case generic // 普通 Git 仓库（仅支持 PAT 密码认证）
}
```

### 3.2 账号模型 (AccountInfo)
存储在 `UserDefaults` 中，敏感的 Token 存储在 `Keychain` 中。
```swift
struct AccountInfo: Codable, Identifiable, Hashable {
    let id: UUID             // 用于 Keychain Account 隔离
    var username: String       // 平台用户名（如 hl13571）
    var platform: GitPlatform
    var serverURL: String?     // 针对私有部署 GitLab 的实例地址（如 https://gitlab.company.com）
}
```

### 3.3 仓库模型 (RepositoryInfo)
存储在 `UserDefaults` 中。
```swift
struct RepositoryInfo: Codable, Identifiable, Hashable {
    let id: UUID             // 用于本地沙盒目录隔离 (repositories/id/)
    var name: String         // 仓库显示名称
    var url: String          // Git 远程 URL
    var branch: String       // 同步分支
    var accountID: UUID?     // 关联的账号 ID（若为 nil 则表示无需认证的公开仓库）
}
```

---

## 4. 存储与安全隔离 (Storage & Security)

### 4.1 本地沙盒目录隔离
所有仓库克隆在沙盒的 `Documents/repositories/` 目录下，以仓库的 `id` (UUID) 作为子目录名：
```text
Documents/
└── repositories/
    ├── 8F9D2A1B-4C3E-4D5F-8A9B-0C1D2E3F4A5B/  (仓库 A)
    │   ├── .git/
    │   └── notes/
    └── 3A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C5D/  (仓库 B)
        ├── .git/
        └── notes/
```

### 4.2 Keychain 安全凭证隔离
使用 `AccountInfo.id` (UUID 字符串) 作为 Keychain 的 `kSecAttrAccount`，实现多账号 Token 的安全隔离：
* **Service**: `com.gitsreader.pat`
* **Account**: `AccountInfo.id.uuidString` (例如: `8F9D2A1B-4C3E-4D5F-8A9B-0C1D2E3F4A5B`)
* **Value**: `access_token`

---

## 5. 核心业务流程 (Workflows)

### 5.1 OAuth 设备流登录流程
```text
[App] --(1. 请求设备码)--> [GitHub/GitLab API]
[App] <-- (返回 user_code & verification_uri) -- [GitHub/GitLab API]
[App] --(2. 引导跳转)--> [系统浏览器输入 user_code 授权]
[App] --(3. 轮询 Token)--> [GitHub/GitLab API]
[App] <-- (4. 授权成功，返回 access_token) -- [GitHub/GitLab API]
```

### 5.2 仓库克隆与同步流程
1. `GitSyncService` 接收目标 `RepositoryInfo`。
2. 根据 `RepositoryInfo.id` 确定本地沙盒路径：`Documents/repositories/\(id)/`。
3. 若 `accountID` 不为空，从 Keychain 中读取 `accountID.uuidString` 对应的 Token。
4. 调用 `SwiftLibgit2` 传入 Token，执行浅克隆或 Fetch 同步。

### 5.3 仓库切换流程
1. 用户在侧边栏点击切换仓库。
2. App 更新全局 `activeRepositoryID`。
3. `FileScannerService` 监听到变更，将扫描根路径切换为 `Documents/repositories/\(activeRepositoryID)/`。
4. SwiftUI 视图层即时刷新，展示新仓库的笔记列表。

---

## 6. UI/UX 交互设计 (iPad & iPhone)

### 6.1 iPad 侧边栏 (NavigationSplitView)
采用三栏布局：
1. **最左侧（第一栏，宽度 70pt）**：垂直排列所有已连接仓库的圆形图标（类似 Slack/Discord 侧边栏），底部有 `+` 按钮用于新增仓库。
2. **中间（第二栏）**：当前激活仓库的文件夹与笔记列表。
3. **右侧（第三栏）**：笔记 Markdown 渲染与阅读区。

### 6.2 iPhone 抽屉视图 (Drawer)
在 iPhone 上，最左侧的仓库列表默认隐藏，用户可以通过：
* 点击左上角导航栏的“仓库”图标。
* 或从屏幕左侧向右滑动。
拉出半屏抽屉视图进行仓库切换。
