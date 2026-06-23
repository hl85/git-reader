# Gits Reader 产品与技术设计文档 (PDD/TDD)

> 本文档是 GitsReader 项目的唯一设计真理源，整合了产品方案、技术架构、实现细节与演进规划。

---

## 1. 产品设计方案 (PDD)

### 1.1 产品定位与核心价值

* **定位**：专为 Obsidian + Git 用户打造的 iOS 移动端"阅读优先 + 轻量编辑"看板与阅读器。
* **核心价值**：极速浅克隆、完美的 Obsidian 语法原生渲染、标签属性编辑与双向同步，彻底解决移动端查阅与轻量管理笔记的痛点。

### 1.2 功能范围边界

| 维度 | 已交付 (MVP + P0/P1) | 规划中 (P2+) |
|------|--------|---------------|
| 仓库管理 | 单仓库 + 分支可配置；多仓库管理 + OAuth 登录（已实现，见 §3） | — |
| 文件浏览 | 两级导航：文件夹 + 文件列表 → 笔记阅读页 | 标签聚合页、反向链接图谱 |
| 笔记链接 | `[[笔记名]]` + `[[笔记名\|别名]]` + `[[folder/笔记名]]`（路径型，取末段匹配） | `![[嵌入]]`、`[[#标题]]`、`[[^块引用]]` |
| 搜索 | 文件名 + Frontmatter 字段（title/tags/aliases） | 全文搜索 |
| 同步 | 只读同步：App 启动自动 Pull + 下拉刷新 / 同步按钮；标签编辑同步：commit + fetch + merge + push | 后台静默拉取 |
| 认证 | PAT（Keychain 安全存储）+ OAuth 设备流（GitHub/GitLab） | SSH Key |
| 离线 | 缓存上次同步数据 + UI 标记离线 | — |
| 图片 | 沙盒本地文件 + 内存缓存层 | 缩略图预生成 |
| Markdown 渲染 | 标题/段落/列表（嵌套缩进）/代码块（语法高亮）/引用块/表格/分割线 | — |
| 阅读工具 | 文本选择拷贝、标签编辑、拷贝全文、长图导出、PDF 导出 | — |
| 标签编辑 | Frontmatter tags 编辑 → 本地 commit → fetch → merge → push（含 push 权限前置校验） | — |
| 属性模板 | 可配置的 Frontmatter 属性模板（date/enum/tags/text 字段类型） | — |
| 闪屏动画 | "书卷与墨水" 启动动画（2.2s 矢量绘制） | — |
| 多语言 | 7 种语言（英/简中/繁中/日/德/法/韩），跟随系统 + 手动切换 | — |
| 编辑范围 | 仅支持 Frontmatter 标签属性编辑，正文不可编辑 | 正文编辑 |

### 1.3 UI/UX 视觉风格 (Claude 风格)

借鉴 Claude 的美学设计，APP 采用高知识感、沉浸式的排版布局：

* **色彩微调**：主背景采用温暖的细腻米白（Light mode: `#FBFBFA`）与深邃炭黑（Dark mode: `#1A1A1A`）。边框与分割线使用极淡的灰色（`#E5E5E0`），减少视觉噪音。
* **字体排版**：正文首选系统 Serif 字体（如宋体/New York），代码与元数据使用 SF Mono，严格控制字间距与行高（正文行高 `1.6`），确保长文阅读的舒适度。
* **卡片设计**：组件采用无阴影、微圆角（`8pt`）、细边框的扁平卡片样式，通过留白（Padding）来划分视觉层级。

#### 闪屏动画："书卷与墨水" (The Ink & Scroll)

* **核心创意**：极简线条如墨水般绘制出 Git 分支（书脊），随后平滑展开成一本书的轮廓（书卷），最后淡入 Serif 字体的 "GitsReader" 标题。
* **色彩适配**：
  * Light Mode：背景 `#FBFBFA`，书卷线条 `#1A1A1A`，书脊与节点 `#D97757`（橘红色）
  * Dark Mode：背景 `#101010`，书卷线条 `#E8E8E4`，书脊与节点 `#D97757`
* **动画时间轴（总 2.2 秒）**：

  | 阶段 | 时间轴 | 视觉表现 | 技术 |
  |:---|:---|:---|:---|
  | 1. 墨水绘制 (Spine) | 0.0s - 0.6s | 竖线从上至下绘制（Git 主分支） | `Path` + `trim(to:)` |
  | 2. 书卷展开 (Pages) | 0.4s - 1.4s | 以竖线为书脊，左右书页线条展开 | `LeftPageShape` + `RightPageShape` + `trim` |
  | 3. 节点与文字 (Fade In) | 1.2s - 2.2s | 书脊两端淡出 Git 节点圆点，下方淡入标题 | `opacity` + `offset(y)` + `scaleEffect` |

* **生命周期**：`SplashWrapperView` 展示 2.5 秒（2.2s 动画 + 0.3s 缓冲），结束后通过 `.opacity` 平滑淡出过渡到主界面。
* **性能**：全矢量 SwiftUI 绘制，零外部图片/Lottie 依赖，内存占用接近 0。

### 1.4 核心交互流程与特性

#### 导航模型

**iPhone**：`NavigationStack` Push（单栏导航）+ 抽屉式侧边栏

```
App Root
├── SplashWrapperView        (闪屏动画 2.5s)
│
└── MainContainerView        (按 userInterfaceIdiom 分流)
    ├── RepoConfigView       (首次使用：欢迎页 + 添加仓库入口 + OAuth 登录)
    │
    └── iPhone 布局          (已配置仓库)
        ├── 抽屉式 SidebarView  (仓库切换 + 账号管理，左滑/点击拉出)
        └── NavigationStack
            ├── FileListView     (首页：文件夹/文件列表 + 搜索 + 同步按钮)
            │   └── Push → NoteReaderView   (笔记正文)
            │   └── Push → NoteReaderView   (WikiLinks 跳转)
            └── SettingsView     (仓库信息、账号管理、属性模板、语言切换)
```

**iPad**：`NavigationSplitView` 三栏布局（见 §3.6）

选择 NavigationStack Push 而非底部 TabBar 或多栏布局（iPhone 端），因为：
- iOS 原生导航体验，零学习成本
- 全屏阅读与 Claude 沉浸式美学天然契合
- NavigationStack 自动管理返回栈和手势

#### 同步策略

App 支持两种同步模式：

**只读同步**（`sync()`）：用于常规拉取，不产生本地改动。

| 触发时机 | 方式 |
|----------|------|
| App 从后台进入前台（`scenePhase == .active`） | 自动 Pull |
| 目录页手动下拉 | `.refreshable` 刷新 |
| 目录页同步按钮 | 手动触发 |

**标签编辑同步**（`commitAndSync(fileURL:)`）：用户编辑 Frontmatter 标签后保存时触发。

| 步骤 | 操作 |
|------|------|
| 0. 权限校验 | 通过 `git-receive-pack` 探测 Token 是否有 push 权限，无权限则立即报错，避免产生未同步的本地 commit |
| 1. 本地提交 | `git index add` + `git index write` + `git commit`（签名：Gits Reader \<gitsreader@example.com\>） |
| 2. 拉取远程 | `git fetch` 获取远程分支增量 |
| 3. 合并解决 | `git merge`（将远程 `origin/{branch}` 合并到本地，处理冲突） |
| 4. 推送远程 | `git push` 将本地 commit 推送到 `refs/heads/{branch}` |

* **编辑边界**：仅支持 Frontmatter 标签属性编辑，正文不可编辑，最大程度降低多端冲突风险。
* **只读同步的强制覆盖**：常规 `sync()` 仍采用 `fetch + reset --hard`，以远程强行覆盖本地，保证只读场景下的一致性。

#### 折叠式 Frontmatter 卡片

文章顶部默认展示一个 Claude 风格的标签面板：

* **收起状态**：仅展示标题与基础元数据（如 `Tags`, `Updated`），高度固定。
* **展开状态**：点击展开完整 YAML 键值对，采用双列 Key-Value 纯文本排版。

#### 智能路径修复

用户在阅读包含本地图片的笔记时，图片能无缝秒开，无需任何手动配置。

#### 阅读页实用功能

笔记阅读页（`NoteReaderView`）提供以下操作：

* **文本选择与拷贝**：主容器应用 `.textSelection(.enabled)`，SwiftUI 原生支持拖动选择、放大镜与拷贝气泡。
* **右上角 `•••` 更多菜单**：
  * **设置属性标签**：弹出半屏 Sheet 编辑 Frontmatter tags，保存后回写本地 Markdown 文件并刷新。
  * **拷贝全文文本**：将 Markdown 源码写入系统剪贴板。
  * **保存整页长图**：离屏渲染（`UIHostingController` + `UIGraphicsImageRenderer`）将整篇笔记渲染为超长 `UIImage`，通过 `UIActivityViewController` 分享/保存。
  * **导出为 PDF**：使用 `UIGraphicsPDFRenderer` 将内容绘制到 PDF 上下文，生成 `.pdf` 文件分享/保存。

### 1.5 核心用户故事

1. **我是一名 Obsidian 用户**，想在通勤时翻阅我的知识库笔记，但不能编辑以避免多端冲突。
2. **我粘贴 PAT Token** 到 App 里，点击同步，所有 `.md` 笔记就出现在文件列表中。
3. **我点击一篇笔记**，看到 Claude 风格的 Frontmatter 卡片和衬线体正文，中间穿插的本地图片完美显示。
4. **我点击 `[[另一篇笔记]]`**，App Push 到目标笔记；返回即回到原文。
5. **我在地铁里没信号**，App 显示上次同步的内容，顶部标着「离线模式」。
6. **我有多个 Obsidian 仓库**，通过 OAuth 登录 GitHub 后，在侧边栏一键切换不同仓库。
7. **我在 iPad 上阅读**，左侧文件列表常驻，右侧显示笔记正文，并排浏览无需来回切换。
8. **我喜欢这篇笔记**，点击「导出为 PDF」保存到本地文件，方便分享给同事。

---

## 2. 技术架构与选型设计 (TDD)

### 2.1 整体数据流与组件关系

整个应用的渲染管线分为 **数据拉取 → 文件解析 → 语法重写 → 原生渲染** 四个阶段：

```
[Remote Git Repo]
    │ swift-libgit2: Shallow Clone (HEAD only)
    ▼
[iOS Sandbox (Documents/repositories/{UUID}/)]
    │ Read .md + static assets
    ▼
[Preprocessor: FrontmatterSplitter]
    ├─→ YAML block → Yams 解析 → SwiftUI 折叠卡片
    └─→ Markdown body →
            │
            ▼
        [ObsidianElementRewriter]  (AST 改写)
            │ WikiLinks [[...]] → Link 节点 (app://note/...)
            │ Image 相对路径 → sandbox file://
            │
            ▼
        [MarkdownBlockClassifier]  (块类型分类)
            │ AST 节点 → BlockElement 枚举
            │   .heading / .paragraph / .unorderedList(depth)
            │   .orderedList(depth) / .codeBlock(language)
            │   .blockquote / .table / .thematicBreak
            │
            ▼
        [BlockView]  (SwiftUI 原生渲染)
            │ switch BlockElement → 对应 View
            │ CodeBlockView → Highlightr 语法高亮
            │ ImageView → Nuke 内存缓存
```

### 2.2 Git 同步模块设计 (`swift-libgit2`)

由于采用**只读且浅克隆**的策略，本地不维护复杂的 Git 状态机，只需每次同步时覆盖最新 Top 节点。

#### 执行逻辑

**只读同步（`sync()`）** — 常规拉取，不产生本地改动：

```
首次使用：clone(depth=1, single-branch, downloadTags=none) → 浅克隆到沙盒
后续同步：fetch(refspec=单分支, depth=1, downloadTags=none) → 获取远程 HEAD 增量
          reset(hard, origin/分支名) → 覆盖本地
若网络不可达：保留沙盒现有文件，标记 offline = true
```

**标签编辑同步（`commitAndSync(fileURL:)`）** — 用户编辑 Frontmatter 标签后触发：

```
0. checkPushPermission: 通过 GET /info/refs?service=git-receive-pack 探测写权限
1. commitLocalChanges: git index add → write → commit（签名: Gits Reader）
2. fetchLatest: 拉取远程增量
3. mergeRemoteChanges: 合并 origin/{branch} 到本地（处理冲突）
4. pushLatest: git push refs/heads/{branch}:refs/heads/{branch}
```

#### 实现细节

1. **浅克隆配置**：通过 `GitCloneOptions` / `GitFetchOptions` 配置以下参数：
   * `fetchOpts.depth = GitFetchDepthT(rawValue: 1)` — 仅拉取最新 1 层 commit
   * `fetchOpts.downloadTags = .gitRemoteDownloadTagsNone` — 不下载 tag 引用
   * `cloneOpts.checkoutBranch = branch` — 单分支克隆
   * 后续 `fetch` 使用精确 refspec `refs/heads/{branch}:refs/remotes/origin/{branch}`

2. **可配置深度**：`GitSyncService.shallowDepth` 持久化到 UserDefaults（默认 1），可调整为更大值以获取更多历史。

3. **强制覆盖策略**：本地保证只读，同步时直接执行 `Hard Reset`，以远程分支强行覆盖本地，不进行三方合并。

4. **可配置分支**：用户在 RepoConfigView 输入分支名（默认 `main`），持久化到 UserDefaults（key: `repoBranch`），支持 master/develop 等分支仓库。

### 2.3 Markdown 解析与重写模块 (`swift-markdown`)

兼容 Obsidian 特有格式的核心层，由前置拦截器（FrontmatterSplitter）、AST 转换器（ObsidianElementRewriter）和块类型分类器（MarkdownBlockClassifier）组成。

#### Frontmatter 分离 (FrontmatterSplitter)

在将文本喂给 `swift-markdown` 之前，通过正则 `^---[\s\S]*?---` 切分顶部的 YAML 块。

```swift
struct NoteContent {
    let frontmatterYAML: String?
    let pureMarkdownBody: String
}
```

分离出的 `frontmatterYAML` 交由 `Yams` 解析为字典，提供给 SwiftUI 折叠卡片组件渲染。

#### Obsidian 语法 AST 改写 (ObsidianElementRewriter)

利用 `MarkupRewriter` 遍历语法树，修改图片节点和 WikiLinks 节点：

* **图片路径改写**：`visitImage` 将相对路径拼接到当前沙盒目录，转换为 `file://` 绝对路径。
* **WikiLinks 改写**：`visitText` 解析 `[[note]]` 和 `[[note|alias]]`，生成 `destination = "app://note/noteName"` 的 Link 节点。

#### WikiLinks 路由方案

**关键决策**：Rewriter 生成内部 scheme（`app://note/笔记名`），由 View 层完成最终路由，解耦 AST 层和文件系统层。

**View 层路由逻辑**：`NoteReaderView` 拦截 Link 点击，若 destination 以 `app://note/` 开头，提取笔记名，在预构建的 `[笔记名: 文件路径]` 字典中查找 → 读取对应 `.md` → Push 新 `NoteReaderView`。若未找到，显示 Toast。

**匹配规则**：
* 大小写不敏感，取文件路径最后一段不含扩展名的文件名
* `[[target|别名]]` 链接显示「别名」，跳转目标仍为 `target`
* **路径型链接**：`[[folder/note]]` 取最后一段 "note" 进行文件匹配（`components(separatedBy: "/").last`），与 View 层 `url.lastPathComponent` 行为一致

#### 块类型分类器 (MarkdownBlockClassifier)

将 `swift-markdown` AST 节点映射为 `BlockElement` 枚举，作为纯函数实现，便于 TDD 测试：

```swift
enum BlockElement {
    case heading(HeadingData)
    case paragraph
    case unorderedList(depth: Int)
    case orderedList(depth: Int)
    case codeBlock(CodeBlockData)
    case blockquote(children: [BlockElement])
    case table(TableData)
    case thematicBreak
    case unknown
}
```

* `classify(_ markup: Markup) -> BlockElement` — AST 节点映射为枚举
* `classifyTable(_ table: Table) -> TableData` — 提取表头和行数据
* `listDepth(_ markup: Markup) -> Int` — 计算嵌套列表层级

### 2.4 UI 渲染模块设计

经过 Rewriter 处理后，AST 通过 `MarkdownBlockClassifier` 分类为 `BlockElement` 枚举，再由 `BlockView` 通过 `switch` 分发到对应的 SwiftUI 子视图渲染。

#### 渲染组件

| 块类型 | 渲染组件 | 说明 |
|--------|----------|------|
| heading | 标题 `Text` | Serif 字体，按层级递减字号 |
| paragraph | 段落 `Text` | Serif 字体，行间距 6pt |
| unorderedList | `UnorderedListView` | 传入 `depth` 控制缩进 `.padding(.leading, depth * 16)` |
| orderedList | `OrderedListView` | 同上，嵌套缩进 |
| codeBlock | `CodeBlockView` | Highlightr 语法高亮 + 顶部语言标签 |
| blockquote | `BlockQuoteView` | 左侧竖线 + 引用样式 |
| table | `TableView` | 表头加粗 + 斑马纹行 |
| thematicBreak | `ThematicBreakView` | 细灰色分割线 |

#### 代码语法高亮 (Highlightr)

* **LanguageNormalizer**：纯函数，将常见语言别名映射为 Highlightr 支持的标准名（`ts` → `typescript`、`py` → `python`、`sh` → `bash` 等），未知返回 `"plaintext"`。
* **CodeHighlighting 协议**：`highlight(code: String, language: String) -> AttributedString`，主 target 用 `HighlightrCodeHighlighter` 实现。
* **性能优化**：Highlightr 首次调用有约 50ms 初始化开销，`CodeBlockView.onAppear` 时异步高亮，先显示纯文本再替换。

### 2.5 认证与安全

#### PAT 认证（MVP）

- 用户在 RepoConfigView 输入 `https://github.com/user/repo.git` + PAT + 分支名
- **连接测试与克隆分离**：
  - **连接测试**：配置页仅通过原生 `URLSession` 发起轻量级 HTTP 请求（`GET /info/refs?service=git-upload-pack`，带 Basic Auth）进行连接测试，避免在登录页进行耗时 `git clone`。
  - **后台克隆**：测试通过后保存配置并进入主界面。`FileListView` 检测到本地仓库不存在时，自动在后台触发 `git clone`，展示加载进度。失败时提供"重试克隆"按钮。
- PAT 存储于 iOS Keychain（`kSecClassGenericPassword`，`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`）
- 仓库 URL 和分支名持久化到 UserDefaults
- 认证方式：将 PAT 嵌入 URL（`https://token:{PAT}@host/repo.git`），libgit2 通过 URL 认证
- 断开连接：`GitSyncService.reset()` 原子化清除 UserDefaults + Keychain + 本地仓库

#### OAuth 设备流认证

详见 §3 OAuth 与多仓库管理设计。

### 2.6 搜索实现

- 同步完成后遍历所有 `.md` 文件，解析 Frontmatter 构建内存索引
- 索引结构：`[{ filename, title, tags, aliases }]`
- **SearchService** 支持 `rebuildIndex(from files: [URL])` 重载方法，接受文件 URL 列表直接构建索引，解耦单例依赖，便于测试
- SwiftUI `.searchable` 修饰符，实时过滤文件名 + Frontmatter 字段（title/tags/aliases 四字段）
- 性能：假设 < 5000 个文件，内存索引足够；`rebuildIndex` 在后台线程执行（约 1-2s），`filter` 为 O(n) 内存扫描，< 100ms 响应

### 2.7 离线策略

- 同步的 `.md` 文件 + 关联图片天然存在于沙盒 Documents 目录
- 网络不可达时：不触发 fetch，直接读取本地文件渲染
- 目录页顶部 `OfflineBanner` 组件提示「离线模式 · 数据截至 X 分钟前」
- `NWPathMonitor` 监听网络状态切换 OfflineBanner 显隐
- 同步按钮置灰或显示「无网络连接」

### 2.8 图片加载

- ObsidianElementRewriter 已改写图片路径为 `file://` 沙盒绝对路径
- 渲染层使用 `NukeUI` (LazyImage)：从 `file://` URL 加载 → 自动内存缓存 → 磁盘即缓存
- 无需生成缩略图，原图已在沙盒
- 图片加载失败显示占位图标

### 2.9 本地化与多语言

- **LocalizationManager**：单例管理当前语言，支持跟随系统语言自动检测 + 用户手动切换
- **支持语言**（7 种）：English、简体中文、繁體中文、日本語、Deutsch、Français、한국어
- 持久化：`@AppStorage("appLanguage")` 存储用户选择，`hasUserSelectedLanguage` 标记是否手动选择
- 使用：通过 `"key".localized` 扩展调用，支持带参数的本地化字符串

### 2.10 属性模板管理

- **PropertyTemplateManager**：单例管理可配置的 Frontmatter 属性模板
- **字段类型**：`date`、`enum`（带选项列表）、`tags`、`text`
- 模板以 YAML 格式存储在 UserDefaults（key: `PropertyTemplateYAML`），用户可在设置页编辑
- 默认模板包含：`date`（date 类型）、`status`（enum: idea/draft/review/reading/archived）、`tags`（tags 类型）
- 用于「设置属性标签」Sheet 中提供结构化的标签编辑界面

### 2.11 测试架构

采用自定义 SPM 测试框架（非 XCTest），通过镜像模块实现 TDD。

#### 架构设计

```
TestPackage/
├── Sources/
│   ├── TestableGitsReader/     # app 代码的 macOS 可编译副本（镜像）
│   │   ├── SearchService.swift
│   │   ├── FileScannerService.swift
│   │   ├── KeychainService.swift
│   │   ├── GitSyncService.swift
│   │   ├── MarkdownBlockClassifier.swift
│   │   ├── LanguageNormalizer.swift
│   │   ├── FrontmatterSplitter.swift
│   │   ├── MarkdownPipeline.swift
│   │   ├── ObsidianElementRewriter.swift
│   │   ├── NetworkMonitor.swift
│   │   └── Models.swift
│   └── TestRunner/            # 测试入口
│       └── main.swift         # 自定义断言 + 测试套件
```

#### TDD 策略

* **双写约束**：可测试逻辑（解析/分类/匹配/语言规范化）抽成纯函数或协议，双写到 `TestableGitsReader` 镜像用自定义断言验证；SwiftUI 渲染部分手动验证。
* **Red-Green-Refactor**：先写失败测试，再写最小实现，最后重构。
* **依赖注入**：`SearchService.rebuildIndex(from:)`、`FileScannerService.scanDirectory(at:)` 等重载方法接受参数注入，不依赖单例。
* **测试运行**：`cd TestPackage && swift run`

#### 测试覆盖（33 个套件，131 个用例）

* **FrontmatterSplitter**：正常/无 Frontmatter/边界情况
* **Models**：NoteContent、SyncError、SearchIndexEntry、KeychainError、FolderNode
* **ObsidianElementRewriter**：图片路径改写、WikiLinks 改写、混合内容
* **MarkdownPipeline**：process(rawText:)、process(fileAt:)、processBody、AST 结构、边缘情况
* **性能测试**：渲染管线性能基准
* **GitSyncService**：testConnection（401/404/超时）、isLocalRepoExists、validateForSync 同步前置校验
* **错误处理验证**：§4.3 错误场景的同步前置校验与连接测试
* **FileScannerService**：scanDirectory(at:)、findNote(named:in:)（含路径型匹配）、extractMetadata
* **SearchService**：rebuildIndex(from:)、filter(query:) 四字段命中、边界用例
* **KeychainService**：CRUD 全流程（save → read → overwrite → delete）
* **MarkdownBlockClassifier**：classify 各块类型、listDepth 嵌套深度
* **LanguageNormalizer**：normalize 别名映射与降级

---

## 3. OAuth 与多仓库管理设计

### 3.1 核心设计决策

| 维度 | 决策方案 | 决策原因 |
|------|----------|----------|
| OAuth 认证方式 | **设备流 (Device Flow)** | 100% 纯客户端实现，无需中转服务器，无 Client Secret 泄露风险 |
| GitLab 兼容性 | **官方云端 + 私有部署** | 覆盖企业、高校等内网使用私有 GitLab 实例的用户 |
| 多仓库管理 UI | **侧边栏/抽屉视图** | 切换高效，适配 iPad 大屏分栏布局 (NavigationSplitView) |
| Token 共享机制 | **按账号/平台共享** | 一个账号可关联多个仓库，避免重复授权 |
| 本地存储隔离 | **UUID 目录隔离** | 每个仓库独立 UUID 目录，数据互不干扰 |

### 3.2 数据模型

```swift
// 平台枚举
enum GitPlatform: String, Codable {
    case github
    case gitlab
    case generic  // 普通 Git 仓库（仅支持 PAT 认证）
}

// 账号模型（存 UserDefaults，Token 存 Keychain）
struct AccountInfo: Codable, Identifiable, Hashable {
    let id: UUID              // Keychain Account 隔离键
    var username: String
    var platform: GitPlatform
    var serverURL: String?    // 私有部署 GitLab 实例地址
}

// 仓库模型（存 UserDefaults）
struct RepositoryInfo: Codable, Identifiable, Hashable {
    let id: UUID              // 本地沙盒目录隔离键
    var name: String
    var url: String
    var branch: String
    var accountID: UUID?      // 关联账号 ID（nil = 无需认证的公开仓库）
}
```

### 3.3 存储与安全隔离

#### 本地沙盒目录隔离

所有仓库克隆在沙盒 `Documents/repositories/` 下，以仓库 `id` (UUID) 作为子目录名：

```
Documents/
└── repositories/
    ├── 8F9D2A1B-.../  (仓库 A)
    │   ├── .git/
    │   └── notes/
    └── 3A1B2C3D-.../  (仓库 B)
        ├── .git/
        └── notes/
```

#### Keychain 凭证隔离

使用 `AccountInfo.id` (UUID 字符串) 作为 `kSecAttrAccount`，实现多账号 Token 安全隔离：
* **Service**: `com.gitsreader.pat`
* **Account**: `AccountInfo.id.uuidString`
* **Value**: `access_token`

向后兼容：未传入 `accountID` 时默认使用原有的 `"personal-access-token"` 账户。

### 3.4 OAuth 设备流认证流程

```
[App] --(1. 请求设备码)--> [GitHub/GitLab API]
[App] <-- (返回 user_code & verification_uri) -- [GitHub/GitLab API]
[App] --(2. 引导跳转)--> [系统浏览器输入 user_code 授权]
[App] --(3. 轮询 Token)--> [GitHub/GitLab API]
[App] <-- (4. 授权成功，返回 access_token) -- [GitHub/GitLab API]
```

* **GitHubDeviceFlowService**：`requestDeviceCode()` 获取 user_code/verification_uri → `pollForToken(deviceCode:interval:)` 轮询获取 access_token
* **GitLabDeviceFlowService**：支持官方云端 (gitlab.com) 和自定义私有部署域名
* **AccountManager**：统一管理已登录账号列表，登录成功后创建 `AccountInfo` 存入 UserDefaults，Token 写入 Keychain

### 3.5 多仓库同步与切换

1. `GitSyncService` 接收目标 `RepositoryInfo`，根据 `id` 确定本地沙盒路径：`Documents/repositories/{id}/`
2. 若 `accountID` 不为空，从 Keychain 读取对应 Token
3. 调用 `SwiftLibgit2` 传入 Token，执行浅克隆或 Fetch 同步
4. 用户切换仓库时更新全局 `activeRepositoryID`，`FileScannerService` 监听变更并重新扫描

### 3.6 UI/UX 交互设计

#### iPad 侧边栏 (NavigationSplitView 三栏)

1. **最左侧（宽度 70pt）**：垂直排列所有已连接仓库的圆形图标（类似 Slack/Discord），底部 `+` 按钮新增仓库，支持点击切换、长按删除/编辑
2. **中间栏**：当前激活仓库的文件夹与笔记列表
3. **右侧栏**：笔记 Markdown 渲染与阅读区

#### iPhone 抽屉视图 (Drawer)

仓库列表默认隐藏，用户可通过点击左上角导航栏"仓库"图标或从屏幕左侧向右滑动拉出半屏抽屉视图进行仓库切换。

#### 新增仓库弹窗 (AddRepositoryView)

* 输入 Git URL + 选择分支的表单
* "关联账号"下拉菜单，展示已登录账号，提供"添加新账号"入口

#### 账号管理 (AccountManagementView)

设置页中提供已登录账号列表，支持解绑/退出登录。

---

## 4. 依赖清单

| 库 | 用途 | 版本 | 来源 |
|----|------|------|------|
| swift-libgit2 (local fork) | Git 浅克隆 / fetch / reset | 1.0.1 (local) | `LocalPackages/swift-libgit2-local` |
| swift-markdown | Markdown AST 解析与 Rewriter | 0.7.2 (exact) | SPM |
| Yams | Frontmatter YAML → Swift Dict | ~5.0 | SPM |
| Nuke / NukeUI | 图片内存缓存与异步加载 | ~12.0 | SPM |
| Highlightr | 代码语法高亮 (highlight.js) | ~2.2 | SPM |

> **已移除**：`textual` (gonzalezreal) 和 `MarkdownUI` (swift-markdown-ui) 已在 P1 清理阶段移除，替换为基于 `swift-markdown` AST 的自定义 `BlockView` 渲染方案。

---

## 5. 非功能需求

### 5.1 性能指标

| 指标 | 目标 |
|------|------|
| 冷启动 → 文件列表可交互 | < 3 秒（含 Shallow Clone） |
| 笔记页渲染（含 10 张图片） | < 1 秒 |
| WikiLinks 跳转 | < 500ms（Push 动画内完成） |
| 搜索响应（< 5000 文件） | < 100ms |
| 索引构建（< 5000 文件） | 1-2 秒（后台线程） |
| Highlightr 首次高亮 | ~50ms（异步，先显示纯文本） |
| 长图/PDF 导出 | 1-2 秒（后台离屏渲染） |

### 5.2 兼容性

- 最低支持：iOS 17（NavigationStack / Observable 宏 / NavigationSplitView / SwiftUI 原生 API）
- 设备：iPhone + iPad（`TARGETED_DEVICE_FAMILY: "1,2"`），iPad 支持 Portrait/Landscape 四方向
- 语言：Swift 6.0

### 5.3 错误处理

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

## 6. iPad 适配

### 6.1 当前状态

iPad 适配已基本完成：

* **项目配置**：`TARGETED_DEVICE_FAMILY: "1,2"` 声明支持 iPhone + iPad，iPad 四方向支持
* **导航架构**：`MainContainerView` 通过 `UIDevice.current.userInterfaceIdiom == .pad` 判断，iPad 使用 `NavigationSplitView` 三栏布局（侧边栏 80pt + 文件列表 + 阅读区），iPhone 使用抽屉式双栏布局
* **侧边栏**：`SidebarView` 实现仓库切换、账号管理，支持点击切换/长按删除
* **已修复问题**：
  * `.navigationBarHidden(true)` 泄漏到其他列 → 改用 `.toolbar(.hidden, for: .navigationBar)`
  * iPad sheet 内 `Picker` + `.pickerStyle(.menu)` 导致 sheet 关闭 → 替换为自定义内联下拉列表
  * 详情列冗余 `NavigationStack` 包装移除（NavigationSplitView 已提供导航上下文）

### 6.2 待优化项

| 优先级 | 改造项 | 说明 |
|--------|--------|------|
| P0 | 阅读内容宽度限制 | `.frame(maxWidth: 720)` 居中，解决 iPad 横屏长行可读性 |
| P1 | `horizontalSizeClass` 差异化布局 | `.regular` 下多列网格/更宽卡片 |
| P1 | Toolbar placement 改 `.topBarTrailing` | 适配 Split View 分栏布局 |
| P2 | 悬浮菜单改用 geometry/锚点定位 | 替代硬编码 `.padding(.top, 106)` |

---

## 7. 演进路线

```
MVP (已交付)
  ├─ 单仓 + 文件树 + 阅读 + WikiLinks L1/L2 + 基础搜索
  ├─ 闪屏动画 "书卷与墨水"
  ├─ 多语言本地化（7 种语言）
  └─ 阅读工具：文本选择、拷贝、长图/PDF 导出

P0/P1 (已交付)
  ├─ 搜索服务接入（filename/title/tags/aliases 四字段）
  ├─ 仓库分支可配置
  ├─ Markdown 块元素补全（BlockQuote/Table/ThematicBreak/嵌套列表缩进）
  ├─ 代码语法高亮 (Highlightr)
  ├─ 路径型 WikiLinks ([[folder/note]])
  ├─ 标签属性编辑 + 双向同步（commit + push）
  ├─ Push 权限前置校验
  ├─ 属性模板管理（可配置 Frontmatter 字段）
  └─ 测试架构（TestPackage + TDD，131 个用例）

P2 (已交付)
  ├─ OAuth 登录 (GitHub / GitLab 设备流)
  ├─ 多仓库管理 (UUID 目录隔离 + 侧边栏切换)
  ├─ 健壮性增强（7 种错误场景测试覆盖）
  └─ iPad NavigationSplitView 三栏适配

P3 (已交付)
  ├─ iPad 阅读宽度限制 + horizontalSizeClass 差异化
  ├─ 后台静默拉取
  ├─ 暗色模式自动切换
  └─ 仓库级状态流转及属性规范（.obsidian/gitsreader.yaml 动态模板）
```

---

## 8. 决策汇总

| 问题 | 决策 |
|------|------|
| MVP 范围 | 单仓 + 文件树 + 阅读 + WikiLinks L1/L2 + 基础搜索 |
| 产品定位 | 阅读优先 + 轻量编辑（仅 Frontmatter 标签），非纯只读 |
| 同步模型 | 只读同步（fetch + reset --hard）+ 标签编辑同步（commit + fetch + merge + push） |
| 导航模型 | iPhone: NavigationStack Push / 抽屉式侧边栏；iPad: NavigationSplitView 三栏 |
| WikiLinks 深度 | L1（`[[note]]`）+ L2（`[[note\|alias]]`）+ 路径型（`[[folder/note]]`） |
| WikiLinks 路由 | AST 层生成 `app://note/` scheme，View 层查字典路由，解耦 |
| 同步触发 | 启动自动 + 目录页下拉刷新 + 同步按钮 + 标签保存触发 commitAndSync |
| Git 认证 | PAT → Keychain；OAuth 设备流 → 多账号隔离 |
| Push 权限 | commitAndSync 前置校验（`git-receive-pack` 探测），无权限立即报错 |
| 搜索范围 | 文件名 + Frontmatter 字段（title/tags/aliases） |
| 搜索实现 | 内存索引，无 SQLite，< 5000 文件假设 |
| 离线策略 | 缓存上次同步 + UI 标记离线 |
| 图片处理 | 沙盒本地文件 + 内存缓存（Nuke） |
| Markdown 渲染 | 自定义 BlockView（swift-markdown AST → BlockElement 枚举 → SwiftUI），非 textual/MarkdownUI |
| 代码高亮 | Highlightr (highlight.js) + LanguageNormalizer 别名规范化 |
| 测试架构 | 自定义 SPM 测试框架（TestPackage + TestableGitsReader 镜像 + TestRunner），非 XCTest |
| TDD 策略 | 可测试逻辑抽纯函数/协议，双写到镜像；UI 手动验证 |
| 多仓库隔离 | UUID 目录隔离 (Documents/repositories/{UUID}/) |
| 多账号隔离 | Keychain Account = AccountInfo.id.uuidString |
| 多语言 | 7 种语言，跟随系统 + 手动切换，LocalizationManager 单例管理 |
| 属性模板 | YAML 格式可配置，PropertyTemplateManager 单例，UserDefaults 持久化 |
| 闪屏动画 | 全矢量 SwiftUI 绘制，零外部依赖 |
| 阅读导出 | 离屏渲染 (UIHostingController) + UIGraphicsImageRenderer/UIGraphicsPDFRenderer |
| iPad 适配 | MainContainerView 按 userInterfaceIdiom 分流，NavigationSplitView 三栏 |
| 项目管理 | XcodeGen (project.yml 为唯一真理源) |
| 版本号 | 全自动（Build = Git 提交数，Version = Git Tag），禁止硬编码 |
