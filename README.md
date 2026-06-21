# Gits Reader

> 专为 Obsidian + Git 用户打造的 iOS 移动端"阅读优先 + 轻量编辑"阅读器。

[![Swift](https://img.shields.io/badge/Swift-6.0+-FA7343?logo=swift)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0+-000000?logo=apple)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

---

## 概述

Gits Reader 让你在 iPhone 和 iPad 上随时翻阅 Obsidian 知识库笔记。通过 Git 浅克隆拉取仓库，支持 WikiLinks 跳转、Frontmatter 阅读和离线浏览，并允许编辑笔记标签属性后双向同步回远程仓库。

| 特性 | 说明 |
|------|------|
| 📖 **阅读优先** | Claude 风格衬线体排版、温暖配色、沉浸式阅读体验 |
| ⚡ **极速同步** | Git shallow clone（depth=1），启动秒级拉取 |
| 📝 **WikiLinks** | `[[笔记]]` / `[[笔记\|别名]]` / `[[folder/笔记]]` 点击跳转 |
| 🏷️ **标签编辑** | 编辑 Frontmatter 标签属性，commit + push 双向同步 |
| 🔍 **搜索** | 文件名 + Frontmatter 字段（title/tags/aliases）实时过滤 |
| 📴 **离线** | 缓存上次数据，无网络也能翻阅 |
| 🔐 **安全** | PAT 存储于 iOS Keychain；支持 GitHub/GitLab OAuth 设备流登录 |
| 📦 **多仓库** | UUID 目录隔离，侧边栏一键切换 |
| 🌐 **多语言** | 英/简中/繁中/日/德/法/韩 7 种语言 |
| 🎨 **代码高亮** | Highlightr (highlight.js) 语法高亮 |
| 📱 **iPad 适配** | NavigationSplitView 三栏布局，侧边栏 + 文件列表 + 阅读区 |
| 📤 **导出** | 长图导出、PDF 导出、全文拷贝 |

## 页面结构

```
App Root
├── SplashWrapperView              闪屏动画 "书卷与墨水"（2.5s）
│
└── MainContainerView              按 userInterfaceIdiom 分流
    ├── RepoConfigView             首次使用：欢迎页 + 添加仓库 / OAuth 登录
    │
    ├── iPhone                     抽屉式侧边栏 + NavigationStack
    │   ├── SidebarView            仓库切换 + 账号管理
    │   ├── FileListView           文件夹/文件列表 + 搜索 + 同步
    │   │   └── NoteReaderView     笔记阅读 + Frontmatter 卡片 + WikiLinks + 标签编辑
    │   └── SettingsView           仓库信息 + 账号管理 + 属性模板 + 语言切换
    │
    └── iPad                       NavigationSplitView 三栏
        ├── SidebarView            仓库切换侧边栏（80pt）
        ├── FileListView           文件列表
        └── NoteReaderView         阅读区
```

## 技术架构

```
Remote Git Repo
    │ swift-libgit2: Shallow Clone (depth=1)
    ▼
iOS Sandbox (Documents/repositories/{UUID}/)
    │ 读取 .md + 静态资源
    ▼
FrontmatterSplitter
    ├── YAML 块 → Yams 解析 → 折叠卡片
    └── Markdown Body
            │
            ▼
        ObsidianElementRewriter (AST 改写)
            ├── WikiLinks [[...]] → Link 节点 (app://note/...)
            └── Image 相对路径 → file:// 沙盒路径
            │
            ▼
        MarkdownBlockClassifier (块类型分类)
            │ AST 节点 → BlockElement 枚举
            │
            ▼
        BlockView (SwiftUI 原生渲染)
            ├── 代码块 → Highlightr 语法高亮
            └── 图片 → Nuke 内存缓存
```

**同步流程**：

- **只读同步**（`sync()`）：`fetch + reset --hard`，以远程强行覆盖本地
- **标签编辑同步**（`commitAndSync`）：`push 权限校验 → commit → fetch → merge → push`

## 依赖

| 库 | 用途 |
|----|------|
| [swift-libgit2](https://github.com/swift-developer-tools/swift-libgit2) (local fork) | Git 浅克隆 / fetch / reset / commit / push |
| [swift-markdown](https://github.com/swiftlang/swift-markdown) | Markdown AST 解析与 Rewriter |
| [Yams](https://github.com/jpsim/Yams) | Frontmatter YAML → 字典 |
| [Nuke](https://github.com/kean/Nuke) | 图片内存缓存与异步加载 |
| [Highlightr](https://github.com/raspu/Highlightr) | 代码语法高亮 (highlight.js) |

## 项目结构

```
git-reader/
├── project.yml                    # XcodeGen 配置（项目结构唯一真理源）
├── Docs/                          # 产品与技术设计文档
├── Prototype/                     # HTML 交互原型
├── Appstore/                      # 应用商店资源（截图、logo、发布指南）
├── GitReader/                     # iOS 工程
│   ├── App/                       # 应用入口 + 路由
│   ├── Models/                    # 数据模型（NoteContent, RepoConfig, GitModels）
│   ├── Services/                  # Git 同步 / 文件扫描 / 搜索 / Keychain / OAuth / 本地化 / 网络监控 / 属性模板
│   ├── Markdown/                  # 解析管线（Splitter → Rewriter → BlockClassifier → Pipeline → 高亮）
│   ├── Theme/                     # 色彩与字体常量
│   ├── Views/                     # SwiftUI 视图
│   │   ├── Splash/                # 闪屏动画
│   │   ├── RepoConfig/            # 欢迎页 + 添加仓库弹窗
│   │   ├── FileList/              # 文件列表 + 主容器 + 侧边栏
│   │   ├── NoteReader/            # 笔记阅读（Frontmatter 卡片 + 正文 + 导出）
│   │   ├── Settings/              # 设置 + 账号管理 + 属性模板设置
│   │   └── Components/            # 共享组件（Toast、OfflineBanner、EmptyState）
│   ├── Resources/                 # 资源文件（图标、本地化）
│   ├── GitReader.entitlements     # 权限配置
│   └── Info.plist
└── TestPackage/                   # 单元测试包（自定义 SPM 测试框架）
    ├── Package.swift
    ├── Sources/TestableGitReader/ # 被测模块拷贝 + 桩（11 个镜像文件）
    └── Sources/TestRunner/        # 自定义测试运行器（33 套件，131 用例）
```

## 快速开始

### 前置条件

- macOS + Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）
- iOS 17.0+ 设备或模拟器

### 运行

1. 生成 Xcode 项目：
   ```bash
   xcodegen generate
   ```
2. 用 Xcode 打开 `GitReader.xcodeproj`
3. 选择 iOS 模拟器（推荐 `iPhone 17 Pro` 或 `iPad Pro 13-inch (M5)`），按 `Cmd+R` 运行

### 配置

启动后进入欢迎页，点击「添加第一个仓库」：

- **方式一（PAT）**：输入仓库地址 + Personal Access Token + 分支名
- **方式二（OAuth）**：通过 GitHub/GitLab 设备流登录，自动拉取仓库列表

Token 将安全存储于 iOS Keychain。

## 版本与构建号管理

本项目已配置**全自动版本与构建号管理**方案，无需手动修改 Xcode 中的 Version 和 Build：

- **Build 号 (CURRENT_PROJECT_VERSION)**：自动设为当前 Git 仓库的**总提交次数 (Commit Count)**。它天然单调递增，且每个 Commit 唯一。
- **Version 号 (MARKETING_VERSION)**：自动读取最新的 **Git Tag**（例如 `v0.1.2` 自动转化为 `0.1.2`）。如果没有打 Tag，则默认使用 `0.1.2`。

### 工作原理

1. 每次在 Xcode 中编译（Build/Archive）时，会自动触发 `Auto Update Version & Build` 脚本。
2. 脚本计算最新的版本号和构建号，并写入 `GitReader/Version.xcconfig` 配置文件。
3. Xcode 项目的 Build Settings 已经与该 `.xcconfig` 关联，从而动态更新 App 的版本信息。
4. `GitReader/Version.xcconfig` 已加入 `.gitignore`，**绝对不会污染 Git 工作区**。

### 如何发布新版本

当你需要发布新版本时，只需在终端打一个 Git Tag 并推送：

```bash
# 1. 打一个版本 Tag (必须以 v 开头，例如 v0.1.3)
git tag -a v0.1.3 -m "Release version 0.1.3"

# 2. 推送 Tag 到远程仓库
git push origin v0.1.3
```

下次编译时，App 的 Version 就会自动变为 `0.1.3`，Build 号也会自动递增为最新的提交数。

## 运行测试

```bash
cd TestPackage && swift run TestRunner
```

预期输出：

```
═══════════════════════════════════════════
  测试完成
═══════════════════════════════════════════
  总计: 131 个用例
  通过: 131 个 ✅
  失败: 0 个 ❌
  通过率: 100.0%
═══════════════════════════════════════════
```

覆盖模块（33 个套件）：
- `FrontmatterSplitter` — YAML 分离逻辑
- `Models` — NoteContent / SyncError / SearchIndexEntry / KeychainError / FolderNode
- `ObsidianElementRewriter` — 图片路径 / WikiLinks 改写
- `MarkdownPipeline` — 完整渲染管线 + AST 结构 + 边缘情况
- `MarkdownBlockClassifier` — 块类型分类 + 嵌套深度
- `LanguageNormalizer` — 语言别名规范化
- `SearchService` — 索引构建 + 四字段过滤 + 边界用例
- `FileScannerService` — 目录扫描 + findNote（含路径型匹配）+ 元数据提取
- `KeychainService` — CRUD 全流程
- `GitSyncService` — 连接测试 + 同步前置校验
- `§4.3 错误处理验证` — 同步前置校验 + 连接测试场景
- 性能测试

## 性能指标

| 指标 | 目标 |
|------|------|
| 冷启动 → 文件列表 | < 3 秒（含浅克隆） |
| 笔记页渲染 | < 1 秒 |
| WikiLinks 跳转 | < 500ms |
| 搜索响应（< 5000 文件） | < 100ms |

## 演进路线

```
MVP (已交付)
  ├─ 单仓 + 文件树 + 阅读 + WikiLinks L1/L2 + 基础搜索
  ├─ 闪屏动画 "书卷与墨水"
  ├─ 多语言本地化（7 种语言）
  └─ 阅读工具：文本选择、拷贝、长图/PDF 导出

P0/P1 (已交付)
  ├─ 搜索四字段（filename/title/tags/aliases）
  ├─ 仓库分支可配置
  ├─ Markdown 块元素补全（BlockQuote/Table/ThematicBreak/嵌套列表）
  ├─ 代码语法高亮 (Highlightr)
  ├─ 路径型 WikiLinks ([[folder/note]])
  ├─ 标签属性编辑 + 双向同步（commit + push）
  ├─ 属性模板管理
  └─ 测试架构（TestPackage + TDD，131 个用例）

P2 (已交付)
  ├─ OAuth 登录 (GitHub / GitLab 设备流)
  ├─ 多仓库管理 (UUID 目录隔离 + 侧边栏切换)
  ├─ 健壮性增强（7 种错误场景测试覆盖）
  └─ iPad NavigationSplitView 三栏适配

P3 (规划中)
  ├─ iPad 阅读宽度限制 + horizontalSizeClass 差异化
  ├─ ![[嵌入]] 支持
  ├─ 全文搜索
  └─ 暗色模式自动切换

P4 (高级特性)
  ├─ 反向链接图谱
  ├─ 标签聚合页
  └─ 后台静默拉取
```

## 协议

MIT License
