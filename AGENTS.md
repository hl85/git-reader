# GitReader AI Agent 开发指南 (AGENTS.md)

本项目是一个 iOS/macOS Swift 应用，使用 **XcodeGen** 管理 Xcode 项目，依赖本地 `swift-libgit2` 进行 Git 仓库读取。

---

## 🚨 核心铁律 (Core Rules)

### 1. XcodeGen 是项目结构的唯一真理源
* **规则**：所有 Target、依赖、Build Phases、Build Settings 均声明在 `project.yml` 中。
* **禁止**：手动修改 `GitReader.xcodeproj` 或 `project.pbxproj`——下次 `xcodegen generate` 会**完全覆盖**。
* **正确做法**：修改 `project.yml` → 运行 `xcodegen generate`。

### 2. 版本号全自动管理，禁止硬编码
* Build 号 = Git 总提交数；Version 号 = 最新 Git Tag（无 Tag 则 `0.1.2`）。
* 由 Pre-Build Script 自动生成 `GitReader/Version.xcconfig`（已 gitignore）。
* **禁止**：在 `project.yml` 或 Xcode 中硬编码 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`。

### 3. 本地 Swift 包约束
* `GitLib` 必须指向本地路径 `LocalPackages/swift-libgit2-local`（上游 `Package.swift` 有相对路径依赖，无法远程解析）。

---

## 🛠️ 常用开发工作流 (Workflows)

### 构建与测试

默认测试与构建设备配置：
* **iPad 模拟器**：`iPad Pro 13-inch (M5)` (iOS 26.5)
* **iPhone 模拟器**：`iPhone 17 Pro` (iOS 26.5)

```bash
# 构建 (macOS)
xcodebuild build -scheme GitReader -destination 'platform=macOS' -quiet

# 构建 (iPad 模拟器)
xcodebuild build -scheme GitReader -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' -quiet

# 构建 (iPhone 模拟器)
xcodebuild build -scheme GitReader -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet

# 测试（如有 Test Target）
xcodebuild test -scheme GitReader -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet

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
├── App/            # 应用入口、AppDelegate、Info.plist
├── Views/          # SwiftUI 视图
├── Models/         # 数据模型
├── Services/       # 业务逻辑、Git 操作、Keychain 等
├── Markdown/       # Markdown 渲染与语法高亮
├── Theme/          # 主题与样式
├── Resources/      # 资源文件（图标、本地化等）
├── Package.swift   # ⚠️ 已删除，依赖全部由 project.yml 管理
project.yml         # ← XcodeGen 配置，项目结构的唯一真理源
LocalPackages/      # 本地 Swift 包（swift-libgit2）
GitReaderTests/     # 单元测试
```

---

## 🔒 安全约束
* 用户 Token（如 GitHub PAT）必须使用 `KeychainService` 存储于 iOS Keychain，**禁止**明文存储在 `UserDefaults` 或文件中。

---

## 📝 代码风格
* 项目未配置 SwiftLint，遵循 Swift 标准 API Design Guidelines。
* SwiftUI 优先，视图使用声明式写法。
