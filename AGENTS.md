# GitReader AI Agent 开发指南 (AGENTS.md)

本项目是一个 iOS Swift 应用，使用 **XcodeGen** 管理 Xcode 项目，依赖本地 `swift-libgit2` 进行 Git 仓库读取。

---

## 🚨 核心铁律 (Core Rules)

### 1. XcodeGen 是项目结构的唯一真理源
* **规则**：所有 Target、依赖、Build Phases、Build Settings 均声明在 `project.yml` 中。
* **禁止**：手动修改 `GitReader.xcodeproj` 或 `project.pbxproj`——下次 `xcodegen generate` 会**完全覆盖**。
* **正确做法**：修改 `project.yml` → 运行 `xcodegen generate`。
* **新增/删除/重命名文件**：在 `GitReader/` 下创建、删除或重命名任何文件/目录后，**必须立即运行 `xcodegen generate`**，否则 Xcode 无法识别新文件，会导致 `Cannot find '...' in scope` 编译错误。

### 2. 版本号全自动管理，禁止硬编码
* Build 号 = Git 总提交数；Version 号 = 最新 Git Tag（无 Tag 则 `0.1.2`）。
* 由 Pre-Build Script 自动生成 `GitReader/Version.xcconfig`（已 gitignore）。
* **禁止**：在 `project.yml` 或 Xcode 中硬编码 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`。

### 3. 本地 Swift 包约束
* `GitLib` 必须指向本地路径 `LocalPackages/swift-libgit2-local`（上游 `Package.swift` 有相对路径依赖，无法远程解析）。

### 4. Git 同步双模型，禁止混用
项目有两条同步路径，修改同步逻辑时必须确认操作的是哪一条：

| 模型 | 入口 | 流程 | 适用场景 |
|------|------|------|----------|
| **只读同步** | `GitSyncService.sync()` | `fetch + reset --hard` | 常规拉取，以远程强行覆盖本地 |
| **标签编辑同步** | `GitSyncService.commitAndSync(fileURL:)` | `push 权限校验 → commit → fetch → merge → push` | 用户编辑 Frontmatter 标签后保存 |

* **禁止**：在只读同步路径中引入 commit/push 逻辑。
* **禁止**：在 `commitAndSync` 中跳过 `checkPushPermission` 前置校验——否则无 push 权限的用户会产生悬空本地 commit。

### 5. Markdown 渲染走自定义 BlockView，禁止引入 textual/MarkdownUI
* 渲染管线：`swift-markdown AST → ObsidianElementRewriter 改写 → MarkdownBlockClassifier 分类为 BlockElement 枚举 → BlockView switch 分发到 SwiftUI 子视图`。
* **禁止**：引入 `textual` (gonzalezreal) 或 `swift-markdown-ui` 作为渲染层——已在 P1 阶段移除。
* 新增 Markdown 块类型时：在 `MarkdownBlockClassifier` 添加枚举 case + classify 映射，在 `BlockView` 添加对应子视图。
* 代码高亮统一走 `Highlightr` + `LanguageNormalizer`，不引入其他高亮库。

### 6. WikiLinks 路由通过 `app://note/` scheme 解耦
* AST 层（`ObsidianElementRewriter`）只负责生成 `app://note/笔记名` Link 节点，**禁止**在 Rewriter 中解析最终文件路径。
* View 层（`NoteReaderView`）拦截 Link 点击，查 `[笔记名: 文件路径]` 字典完成路由。
* 路径型链接 `[[folder/note]]` 取最后一段匹配（`components(separatedBy: "/").last`）。

### 7. 测试用 TestPackage 自定义框架，非 XCTest
* 测试代码位于 `TestPackage/`，通过 `TestableGitReader` 镜像模块 + `TestRunner` 运行，**不使用 XCTest**。
* 运行测试：`cd TestPackage && swift run TestRunner`
* **双写约束**：修改 `GitReader/` 下可测试逻辑（解析/分类/匹配/语言规范化等纯函数或协议）时，**必须同步更新** `TestPackage/Sources/TestableGitReader/` 中的镜像副本，否则测试编译失败。
* 依赖注入：可测试方法应提供接受参数注入的重载（如 `rebuildIndex(from:)`、`scanDirectory(at:)`），不依赖单例。

---

## 🛠️ 常用开发工作流 (Workflows)

### 构建与测试

默认测试与构建设备配置：
* **iPad 模拟器**：`iPad Pro 13-inch (M5)` (iOS 26.5)
* **iPhone 模拟器**：`iPhone 17 Pro` (iOS 26.5)

```bash
# 构建 (iPad 模拟器)
xcodebuild build -scheme GitReader -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' -quiet

# 构建 (iPhone 模拟器)
xcodebuild build -scheme GitReader -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet

# 测试（自定义 SPM 测试框架，非 xcodebuild test）
cd TestPackage && swift run TestRunner

# 生成项目（修改 project.yml 后必须执行）
xcodegen generate
```

### 添加新文件或目录
在 `GitReader/` 下创建文件后直接运行 `xcodegen generate`，XcodeGen 自动扫描并更新项目。

### 修改项目配置或新增依赖
1. 编辑 `project.yml`（参考 [XcodeGen ProjectSpec](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md)）。
2. 运行 `xcodegen generate`。

---

## 📁 项目结构概览

```
GitReader/
├── App/            # 应用入口、路由
├── Views/          # SwiftUI 视图（Splash/RepoConfig/FileList/NoteReader/Settings/Components）
├── Models/         # 数据模型（NoteContent, RepoConfig, GitModels）
├── Services/       # 业务逻辑（GitSync/Keychain/FileScanner/Search/OAuth/本地化/网络监控/属性模板）
├── Markdown/       # Markdown 渲染管线（Splitter/Rewriter/BlockClassifier/Pipeline/高亮）
├── Theme/          # 主题与样式
├── Resources/      # 资源文件（图标、本地化）
project.yml         # ← XcodeGen 配置，项目结构的唯一真理源
LocalPackages/      # 本地 Swift 包（swift-libgit2）
TestPackage/        # 自定义 SPM 测试框架（TestableGitReader 镜像 + TestRunner）
```

---

## 🔒 安全约束

* 用户 Token（PAT / OAuth access_token）必须使用 `KeychainService` 存储于 iOS Keychain，**禁止**明文存储在 `UserDefaults` 或文件中。
* **多账号隔离**：Keychain 的 `kSecAttrAccount` 必须使用 `AccountInfo.id.uuidString`，禁止多账号共用同一 Account 键。
* PAT 认证：Token 嵌入 URL（`https://token:{PAT}@host/repo.git`），由 libgit2 通过 URL 认证。
* OAuth 认证：使用设备流（Device Flow），100% 纯客户端，**禁止**引入中转服务器或硬编码 Client Secret。

---

## 📐 NavigationSplitView 约束（iPad 适配铁律）

以下三条是踩坑后总结的硬性约束，违反会导致 iPad 上严重 UI 问题：

1. **禁止 `.navigationBarHidden(true)`**：在 `NavigationSplitView` 中该废弃 API 会泄漏到其他列，导致内容列导航栏被隐藏、滚动失效。必须用 `.toolbar(.hidden, for: .navigationBar)`。
2. **iPad sheet 内禁止 `Picker` + `.pickerStyle(.menu)`**：popover 与 sheet presentation 冲突会导致 sheet 关闭。改用自定义内联下拉列表（Button + ScrollView）。
3. **NavigationSplitView 详情列不需要额外包 `NavigationStack`**：split view 已提供导航上下文，重复包装会导致导航行为异常。

---

## 📝 代码风格
* 项目未配置 SwiftLint，遵循 Swift 标准 API Design Guidelines。
* SwiftUI 优先，视图使用声明式写法。
