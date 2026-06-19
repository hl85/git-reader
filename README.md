# Gits Reader

> 专为 Obsidian + Git 用户打造的 iOS 移动端"纯净只读"阅读器。

[![Swift](https://img.shields.io/badge/Swift-6.0+-FA7343?logo=swift)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0+-000000?logo=apple)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

---

## 概述

Gits Reader 让你在 iPhone 上随时翻阅 Obsidian 知识库笔记。通过 Git 浅克隆拉取仓库，零编辑入口杜绝多端合并冲突，支持 WikiLinks 跳转、Frontmatter 阅读和离线浏览。

| 特性 | 说明 |
|------|------|
| 🔒 **只读** | 零编辑入口，无合并冲突风险 |
| ⚡ **极速同步** | Git shallow clone（depth=1），启动秒级拉取 |
| 📝 **WikiLinks** | `[[笔记]]` / `[[笔记\|别名]]` 点击跳转 |
| 🔍 **搜索** | 文件名 + Frontmatter 字段实时过滤 |
| 📴 **离线** | 缓存上次数据，无网络也能翻阅 |
| 🎨 **Claude 美学** | 衬线体排版、温暖配色、沉浸式阅读 |
| 🔐 **安全** | PAT Token 存储于 iOS Keychain |

## 页面结构

```
App Root
├── RepoConfigView         首次使用：输入仓库 URL + PAT
└── NavigationStack
    ├── FileListView        文件夹/文件列表 + 搜索 + 同步
    │   └── NoteReaderView  笔记阅读 + Frontmatter 卡片 + WikiLinks
    └── SettingsView        仓库信息 + 断开连接
```

## 技术架构

```
Remote Git Repo
    │ swift-libgit2: Shallow Clone (depth=1)
    ▼
iOS Sandbox
    │ 读取 .md + 静态资源
    ▼
Frontmatter Splitter
    ├── YAML 块 → Yams 解析 → 折叠卡片
    └── Markdown Body
            │
            ▼
        ObsidianElementRewriter (AST 改写)
            ├── WikiLinks [[...]] → Link 节点
            └── Image 相对路径 → file:// 沙盒路径
            │
            ▼
        textual → SwiftUI AttributedString 渲染
```

## 依赖

| 库 | 用途 |
|----|------|
| [swift-libgit2](https://github.com/swift-developer-tools/swift-libgit2) | Git 浅克隆 / fetch / reset |
| [swift-markdown](https://github.com/swiftlang/swift-markdown) | Markdown AST 解析与 Rewriter |
| [Yams](https://github.com/jpsim/Yams) | Frontmatter YAML → 字典 |
| [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) | AST → SwiftUI 渲染 |
| [Nuke](https://github.com/kean/Nuke) | 图片内存缓存与异步加载 |

## 项目结构

```
git-reader/
├── docs/                           # 产品与技术设计文档
├── prototype/                      # HTML 交互原型
├── GitReader/                      # iOS 工程
│   ├── Package.swift               # SPM 依赖管理
│   ├── App/                        # 应用入口 + 路由
│   ├── Models/                     # 数据模型
│   ├── Services/                   # Git 同步 / 文件扫描 / 搜索 / Keychain
│   ├── Markdown/                   # 解析管线（Splitter → Rewriter → Pipeline）
│   ├── Theme/                      # 色彩与字体常量
│   ├── Views/                      # SwiftUI 视图
│   │   ├── RepoConfig/
│   │   ├── FileList/
│   │   ├── NoteReader/
│   │   ├── Settings/
│   │   └── Components/
└── TestPackage/                    # 单元测试包
    ├── Package.swift
    ├── Sources/TestableGitReader/  # 被测模块拷贝 + 桩
    └── Sources/TestRunner/         # 自定义测试运行器
```

## 快速开始

### 前置条件

- macOS + Xcode 16+
- iOS 17.0+ 设备或模拟器

### 运行

1. 在 Xcode 中打开 `GitReader/` 目录（通过 SPM 打开）
2. 选择 iOS 模拟器，按 `Cmd+R` 运行

### 配置

启动后进入 RepoConfigView，输入：
- **仓库地址**：例如 `https://github.com/user/my-notes.git`
- **Personal Access Token**：GitHub / GitLab 个人访问令牌（至少需 `repo` 权限）

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
  总计: 43 个用例
  通过: 43 个 ✅
  失败: 0 个 ❌
  通过率: 100.0%
═══════════════════════════════════════════
```

覆盖模块：
- `FrontmatterSplitter` — YAML 分离逻辑（10 条）
- `Models` — 数据模型与错误类型（8 条）
- `ObsidianElementRewriter` — 图片路径 / WikiLinks 改写（10 条）
- `MarkdownPipeline` — 完整渲染管线（13 条）
- 性能测试（2 条）

## 性能指标

| 指标 | 目标 |
|------|------|
| 冷启动 → 文件列表 | < 3 秒（含浅克隆） |
| 笔记页渲染 | < 1 秒 |
| WikiLinks 跳转 | < 500ms |
| 搜索响应（< 5000 文件） | < 100ms |

## 演进路线

```
MVP (当前)
  └─ 单仓 + 文件树 + 阅读 + WikiLinks L1/L2 + 基础搜索

P1
  ├─ ![[嵌入]] / 全文搜索 / 暗色模式自动切换
  └─ iPad 适配

P2
  ├─ OAuth 登录 (GitHub / GitLab)
  └─ 多仓库管理

P3
  └─ 反向链接图谱 / 标签聚合页
```

## 协议

MIT License
