# Gits Reader 产品与技术设计文档 (PDD/TDD)

## 1. 产品设计方案 (PDD)

### 1.1 产品定位与核心价值

* **定位**：专为 Obsidian + Git 用户打造的 iOS 移动端"纯净只读"看板与阅读器。
* **核心价值**：零冲突风险、极速浅克隆、完美的 Obsidian 语法原生渲染，彻底解决移动端轻量查阅笔记的痛点。

### 1.2 MVP 范围边界

| 维度 | 范围内 | 范围外（P1+） |
|------|--------|---------------|
| 仓库管理 | 单仓库 | 多仓库切换 |
| 文件浏览 | 两级导航：（首页）文件夹 + 文件列表 →（Push）笔记阅读页 | 标签聚合页、反向链接图谱 |
| 笔记链接 | `[[笔记名]]` + `[[笔记名\|别名]]` 点击跳转（Push） | `![[嵌入]]`、`[[#标题]]`、`[[^块引用]]` |
| 搜索 | 文件名 + Frontmatter 字段（title/tags/aliases） | 全文搜索 |
| 同步 | App 启动自动 Pull + 目录页下拉刷新 / 同步按钮 | 后台静默拉取 |
| 认证 | Personal Access Token（Keychain 安全存储） | SSH Key、OAuth |
| 离线 | 缓存上次同步数据 + UI 标记离线 | — |
| 图片 | 沙盒本地文件 + 内存缓存层 | 缩略图预生成 |
| 编辑 | 零编辑入口 | — |

### 1.3 UI/UX 视觉风格 (Claude 风格)

借鉴 Claude 的美学设计，APP 将采用高知识感、沉浸式的排版布局：

* **色彩微调**：主背景采用温暖的细腻米白（Light mode: `#FBFBFA`）与深邃炭黑（Dark mode: `#1A1A1A`）。边框与分割线使用极淡的灰色（`#E5E5E0`），减少视觉噪音。
* **字体排版**：正文首选系统 Serif 字体（如宋体/New York），代码与元数据使用 SF Mono，严格控制字间距与行高（正文行高 `1.6`），确保长文阅读的舒适度。
* **卡片设计**：组件采用无阴影、微圆角（`8pt`）、细边框的扁平卡片样式，通过留白（Padding）来划分视觉层级。

### 1.4 核心交互流程与特性

#### 导航模型：NavigationStack Push

```
App Root
├── RepoConfigView         (首次使用：输入 URL + PAT)
│
└── NavigationStack (Root)  (已配置仓库)
    ├── FileListView        (首页：文件夹/文件列表 + 搜索 + 同步按钮)
    │   └── NavigationLink → NoteReaderView   (笔记正文)
    │   └── NavigationLink → NoteReaderView   (WikiLinks 跳转)
    └── SettingsView        (右上角入口：仓库信息、更新 Token)
```

选择 NavigationStack Push 而非底部 TabBar 或多栏布局，因为：
- iOS 原生导航体验，零学习成本
- 全屏阅读与 Claude 沉浸式美学天然契合
- NavigationStack 自动管理返回栈和手势

#### 同步策略

| 触发时机 | 方式 |
|----------|------|
| App 从后台进入前台（`scenePhase == .active`） | 自动 Pull |
| 目录页手动下拉 | `.refreshable` 刷新 |
| 目录页同步按钮 | 手动触发 |

* **单向同步仓**：配置 Git 远程仓库后，点击同步即触发静默下拉（Pull）。界面不提供编辑入口，从根本上杜绝多端合并冲突（Merge Conflicts）。

#### 折叠式 Frontmatter 卡片

文章顶部默认展示一个 Claude 风格的标签面板：

* **收起状态**：仅展示标题与基础元数据（如 `Tags`, `Updated`），高度固定。
* **展开状态**：点击展开完整 YAML 键值对，采用双列 Key-Value 纯文本排版。

#### 智能路径修复

用户在阅读包含本地图片的笔记时，图片能无缝秒开，无需任何手动配置。

### 1.5 核心用户故事

1. **我是一名 Obsidian 用户**，想在通勤时翻阅我的知识库笔记，但不能编辑以避免多端冲突。
2. **我粘贴 PAT Token** 到 App 里，点击同步，所有 `.md` 笔记就出现在文件列表中。
3. **我点击一篇笔记**，看到 Claude 风格的 Frontmatter 卡片和衬线体正文，中间穿插的本地图片完美显示。
4. **我点击 `[[另一篇笔记]]`**，App Push 到目标笔记；返回即回到原文。
5. **我在地铁里没信号**，App 显示上次同步的内容，顶部标着「离线模式」。

---

## 2. 技术架构与选型设计 (TDD)

### 2.1 整体数据流与组件关系

整个应用的渲染管线分为 **数据拉取 -> 文件解析 -> 语法重写 -> 原生渲染** 四个阶段：

```
[Remote Git Repo]
    │ swift-libgit2: Shallow Clone (HEAD only)
    ▼
[iOS Sandbox (Documents)]
    │ Read .md + static assets
    ▼
[Preprocessor: Frontmatter Splitter]
    ├─→ YAML block → Yams 解析 → SwiftUI 折叠卡片
    └─→ Markdown body →
            │
            ▼
        [ObsidianElementRewriter]  (AST 改写)
            │ WikiLinks [[...]] → Link 节点
            │ Image 相对路径 → sandbox file://
            │
            ▼
        [textual: AttributedString → SwiftUI]
```

### 2.2 Git 同步模块设计 (`swift-developer-tools/swift-libgit2`)

由于采用**只读且浅克隆**的策略，本地不维护复杂的 Git 状态机，只需每次同步时覆盖最新 Top 节点。

#### 执行逻辑

```
首次使用：clone(depth=1, single-branch, downloadTags=none) → 浅克隆到沙盒
后续同步：fetch(refspec=单分支, depth=1, downloadTags=none) → 获取远程 HEAD 增量
          reset(hard, origin/分支名) → 覆盖本地
若网络不可达：保留沙盒现有文件，标记 offline = true
```

#### 实现细节

1. **浅克隆配置**：通过 `GitCloneOptions` / `GitFetchOptions` 配置以下参数：
   * `fetchOpts.depth = GitFetchDepthT(rawValue: 1)` — 仅拉取最新 1 层 commit，大幅减少首次同步数据量
   * `fetchOpts.downloadTags = .gitRemoteDownloadTagsNone` — 不下载 tag 引用
   * `cloneOpts.checkoutBranch = branch` — 单分支克隆，不拉取其他分支引用
   * 后续 `fetch` 使用精确 refspec `refs/heads/{branch}:refs/remotes/origin/{branch}`，只拉取目标分支的增量

2. **可配置深度**：`GitSyncService.shallowDepth` 持久化到 UserDefaults（默认 1），可调整为更大值以获取更多历史

3. **强制覆盖策略**：由于本地保证只读，若本地文件由于意外发生变动，同步时直接执行 `Hard Reset` 逻辑，以远程分支强行覆盖本地，不进行任何三方合并（Merge）。即使用户意外修改（如 iCloud 同步干扰），也能保证与远程一致性。

### 2.3 Markdown 解析与重写模块 (`swiftlang/swift-markdown`)

这是兼容 Obsidian 特有格式的核心层。我们将构建一个前置拦截器（Preprocessor）与一个基于 `MarkupRewriter` 的 AST 转换器。

#### 方案 1：Frontmatter 的过滤与独立分离

在将文本喂给 `swift-markdown` 之前，通过高效的字符串状态机或正则，将顶部的 YAML 块切分出来。

```swift
// 伪代码：Frontmatter 分离器
struct NoteContent {
    let frontmatterYAML: String?
    let pureMarkdownBody: String
}

func preprocessMarkdown(_ rawText: String) -> NoteContent {
    let regex = try! NSRegularExpression(pattern: "^---[\\s\\S]*?---", options: [])
    // 匹配文章开头的 --- 块
    if let match = regex.firstMatch(in: rawText, options: [], range: NSRange(rawText.startIndex..., in: rawText)) {
        let yamlRange = Range(match.range, in: rawText)!
        let yaml = String(rawText[yamlRange])
        let body = String(rawText[yamlRange.upperBound...])
        return NoteContent(frontmatterYAML: yaml, pureMarkdownBody: body)
    }
    return NoteContent(frontmatterYAML: nil, pureMarkdownBody: rawText)
}
```

*分离出来的 `frontmatterYAML` 将交由独立的 YAML 解析器（如 `Yams`）转化为字典，提供给 SwiftUI 的可收起卡片组件渲染；而 `pureMarkdownBody` 则继续向后传递。*

#### 方案 2：相对路径与 Obsidian 特有语法的 AST 改写

利用 `swift-markdown` 提供的 `MarkupRewriter` 遍历语法树，修改图片节点（`Image`）和 WikiLinks 节点（`Text` 中的 `[[...]]`）。

```swift
class ObsidianElementRewriter: MarkupRewriter {
    let currentFileDirectory: URL // 当前 .md 文件在 iOS 沙盒中的绝对目录 URL
    
    init(currentFileDirectory: URL) {
        self.currentFileDirectory = currentFileDirectory
    }
    
    // 拦截并改写图片节点
    override func visitImage(_ image: Image) -> Markup? {
        guard let source = image.source else { return image }
        
        // 检查是否为本地相对路径 (不包含 http:// 或 https://)
        if !source.contains("://") {
            // 将相对路径拼接到当前沙盒目录，转换为沙盒绝对路径 file://...
            let absoluteURL = currentFileDirectory.appendingPathComponent(source).standardizedFileURL
            var newImage = image
            newImage.source = absoluteURL.absoluteString
            return newImage
        }
        
        return image
    }
    
    // 拦截并改写 WikiLinks 节点 ([[...]] → Link 节点)
    override func visitText(_ text: Text) -> Markup? {
        let pattern = #"\[\[([^\]|#]+)(?:\|([^\]]+))?\]\]"#
        // 捕获组1: 目标笔记名
        // 捕获组2: 可选显示别名
        // 替换为 Link 节点，destination = "app://note/\(noteName)"
        // 在 NoteReaderView 中拦截此 scheme，执行 Push 跳转
        return super.visitText(text)
    }
}
```

#### WikiLinks 路由方案

**关键决策**：不尝试在 Rewriter 中解析最终文件路径，而是生成一个内部 scheme（`app://note/笔记名`），由 View 层完成最终路由。这解耦了 AST 层和文件系统层。

**View 层路由逻辑**：`NoteReaderView` 拦截 Link 点击，若 destination 以 `app://note/` 开头，提取笔记名，在预构建的 `[笔记名: 文件路径]` 字典中查找 → 读取对应 `.md` → 构造新的 `NoteReaderView` 并 Push。若未找到，显示 Toast。

**匹配规则**：大小写不敏感，取文件路径最后一段不含扩展名的文件名。`[[target|别名]]` 链接显示「别名」，跳转目标仍为 `target`。

### 2.4 UI 渲染模块设计 (`gonzalezreal/textual`)

经过重写器处理后，`swift-markdown` 输出的已是带有本地沙盒绝对路径、且剥离了 Frontmatter 的标准高级 AST。

#### SwiftUI 视图层组装

在 View 层，利用 `textual` 强大的 `AttributedString` 渲染能力与 Claude 极简美学样式进行结合：

```swift
import SwiftUI
import Textual // 假设接入的库名称

struct NoteReaderView: View {
    let noteTitle: String
    let frontmatterData: [String: String]?
    let parsedDocument: Document // 由 MarkupRewriter 转换后的 swift-markdown Document
    
    @State private var isFrontmatterExpanded: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. 标题
                Text(noteTitle)
                    .font(.system(.title, design: .serif))
                    .fontWeight(.bold)
                    .foregroundColor(Color("ClaudeTextDark"))
                
                // 2. Obsidian Frontmatter 卡片 (Claude 风格)
                if let frontmatter = frontmatterData, !frontmatter.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("元数据 (Metadata)", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Button(isFrontmatterExpanded ? "收起" : "展开") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isFrontmatterExpanded.toggle()
                                }
                            }
                            .font(.caption)
                            .foregroundColor(Color("ClaudeMutedLink"))
                        }
                        
                        if isFrontmatterExpanded {
                            Divider().background(Color("ClaudeBorder"))
                            ForEach(frontmatter.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                HStack(alignment: .top) {
                                    Text(key)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 80, alignment: .leading)
                                    Text(value)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color("ClaudeCardBackground"))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color("ClaudeBorder"), lineWidth: 1)
                    )
                }
                
                // 3. 正文渲染层 (使用 Textual 库将 AST 直接映射为 SwiftUI 原生文本)
                TextualView(parsedDocument)
                    .textualStyle(
                        TextualStyle()
                            .font(.system(.body, design: .serif)) // 正文用衬线体
                            .lineSpacing(6)
                            .codeFont(.system(.body, design: .monospaced)) // 代码块用等宽体
                            .linkColor(Color("ClaudeLink"))
                    )
            }
            .padding(24)
        }
        .background(Color("ClaudeBackground"))
    }
}
```

### 2.5 认证与安全

- 用户在 RepoConfigView 输入 `https://github.com/user/repo.git` + PAT
- **连接测试与克隆分离**：
  - **连接测试**：在配置页仅通过原生 `URLSession` 发起轻量级 HTTP 请求（`GET /info/refs?service=git-upload-pack`，带 Basic Auth 认证）进行连接测试。这避免了在登录页进行耗时的 `git clone`，且利用系统原生网络库完美处理 SSL 证书验证。
  - **后台克隆**：测试通过后即保存配置并进入主界面。在主界面（`FileListView`）检测到本地仓库不存在时，自动在后台触发 `git clone`，并展示优雅的加载进度。若克隆失败，提供“重试克隆”按钮，不阻塞用户。
- PAT 存储于 iOS Keychain（`kSecClassGenericPassword`，`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`）
- 仓库 URL 和分支名持久化到 UserDefaults
- 认证方式：将 PAT 嵌入 URL（`https://token:{PAT}@host/repo.git`），libgit2 通过 URL 认证
- 配置校验：`GitSyncService.isConfigured` 检查 token + URL 齐全即可，不要求本地仓库已克隆
- 断开连接：`GitSyncService.reset()` 原子化清除 UserDefaults + Keychain + 本地仓库
- 不支持明文存储，不支持 SSH

### 2.6 搜索实现

- 同步完成后遍历所有 `.md` 文件，解析 Frontmatter 构建内存索引
- 索引结构：`[{ filename, title, tags, aliases }]`
- SwiftUI `.searchable` 修饰符，实时过滤文件名 + Frontmatter 字段
- 性能：假设 < 5000 个文件，内存索引足够；无需 SQLite

### 2.7 离线策略

- 同步的 `.md` 文件 + 关联图片天然存在于沙盒 Documents 目录
- 网络不可达时：不触发 fetch，直接读取本地文件渲染
- 目录页顶部 `OfflineBanner` 组件提示「离线模式 · 数据截至 X 分钟前」
- 同步按钮置灰或显示「无网络连接」

### 2.8 图片加载

- ObsidianElementRewriter 已改写图片路径为 `file://` 沙盒绝对路径
- 渲染层使用 `NukeUI` (LazyImage) 或原生 `AsyncImage`：从 `file://` URL 加载 → 自动内存缓存 → 磁盘即缓存
- 无需生成缩略图，原图已在沙盒

---

## 3. 依赖清单

| 库 | 用途 | 版本参考 |
|----|------|----------|
| swift-libgit2 (local fork) | Git 浅克隆 / fetch / reset | 1.0.1 (local) |
| swift-markdown | Markdown AST 解析与 Rewriter | 0.7.2 |
| MarkdownUI (gonzalezreal) | Markdown → SwiftUI 渲染 | ~2.0 |
| Yams | Frontmatter YAML → Swift Dict | ~5.0 |
| Nuke / NukeUI | 图片内存缓存与异步加载 | ~12.0 |

---

## 4. 非功能需求

### 4.1 性能指标

| 指标 | 目标 |
|------|------|
| 冷启动 → 文件列表可交互 | < 3 秒（含 Shallow Clone） |
| 笔记页渲染（含 10 张图片） | < 1 秒 |
| WikiLinks 跳转 | < 500ms（Push 动画内完成） |
| 搜索响应（< 5000 文件） | < 100ms |

### 4.2 兼容性

- 最低支持：iOS 17（NavigationStack / Observable 宏 / SwiftUI 原生 API）
- 设备：iPhone（MVP 不做 iPad 适配）

### 4.3 错误处理

| 错误场景 | 用户可见行为 |
|----------|-------------|
| PAT 无效 / 仓库不存在 | 配置页显示红色错误信息，保留输入内容，回滚已保存的 token |
| Token + URL 不完整 | 同步时提示「未找到 Access Token，请重新连接仓库」 |
| 仓库目录缺失 | 启动时自动在后台触发克隆，并展示克隆进度与重试选项 |
| 网络超时 | 目录页显示离线模式，使用缓存数据 |
| 本地文件被意外删除 | 同步时自动恢复（reset --hard） |
| WikiLinks 目标笔记不存在 | Toast：「未找到笔记 "xxx"」 |
| 图片路径无效 | 显示占位图标替代 |

---

## 5. 演进路线

```
MVP (本次交付)
  └─ 单仓 + 文件树 + 阅读 + WikiLinks L1/L2 + 基础搜索

P1 (快速跟进)
  ├─ ![[嵌入]] / 全文搜索 / 暗色模式自动切换
  └─ iPad 适配 / Stage Manager

P2 (规模扩展)
  ├─ OAuth 登录 (GitHub / GitLab)
  └─ 多仓库管理

P3 (高级特性)
  └─ 反向链接图谱 / 标签聚合页
```

---

## 6. 决策汇总

| 问题 | 决策 |
|------|------|
| MVP 范围 | 标准 MVP：单仓 + 文件树 + 阅读 + WikiLinks L1/L2 + 基础搜索 |
| 导航模型 | NavigationStack Push |
| WikiLinks 深度 | L1（`[[note]]`）+ L2（`[[note\|alias]]`） |
| 同步触发 | 启动自动 + 目录页下拉刷新 + 同步按钮 |
| Git 认证 | Personal Access Token → Keychain |
| 搜索范围 | 文件名 + Frontmatter 字段 |
| 离线策略 | 缓存上次同步 + UI 标记离线 |
| 图片处理 | 沙盒本地文件 + 内存缓存（Nuke） |
