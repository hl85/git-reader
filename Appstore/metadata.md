# Gits Reader - App Store 商店元数据

本文档整理了发布到 App Store 所需的所有文本素材，您可以直接复制使用。

---

## 1. 基础信息 (Basic Info)

* **应用名称 (App Name)**: `Gits Reader` (已确定，限制 30 字符以内)
* **副标题 (Subtitle)**: (限制 30 字符以内，突出核心定位)
  * **推荐方案**：`Git 驱动的 Markdown 笔记阅读器` (21 字符) —— 中性表述，避免品牌关联风险。
  * **备选方案 1**：`只读无冲突的 Git 笔记阅读器` (21 字符) —— 强调”只读、无冲突”的安全属性。
  * **备选方案 2**：`沉浸式 Git 笔记极速阅读器` (20 字符) —— 强调 Claude 风格的沉浸式美学与极速体验。

---

## 2. 搜索与推广 (Search & Promotion)

* **关键词 (Keywords)**: (限制 100 字符，用英文逗号分隔，不要有空格，不要重复应用名称)
  `git,obsidian,markdown,reader,notes,sync,gitreader,wiki,markdown阅读器,笔记同步,只读,知识库,个人知识管理,pkm`
  *(解析：覆盖了 Git、Obsidian、Markdown、同步、只读、知识管理等核心搜索词)*

* **宣传文本 (Promotional Text)**: (限制 170 字符，显示在 App Store 描述顶部，可随时修改无需审核)
  `专为 Git + Markdown 用户打造的 iOS 极速只读笔记阅读器。兼容 Obsidian 格式，零冲突风险，一键同步，完美渲染 WikiLinks 与本地图片，带给您温润沉浸的阅读体验。` (80 字符)

---

## 3. 详细描述 (Description)

*(限制 4000 字符，用于详细介绍 App 的功能、优势和适用场景)*

```text
Gits Reader —— 专为 Git + Markdown 用户打造的 iOS 移动端”纯净只读”看板与阅读器，完美兼容 Obsidian 笔记格式。

您是否也曾遇到过这些痛点？
- 想在手机上随时翻阅自己的 Obsidian 知识库，但又担心移动端编辑导致复杂的 Git 合并冲突（Merge Conflicts）？
- 移动端 Git 客户端克隆速度慢、配置繁琐？
- 笔记中的 WikiLinks 双链跳转和本地图片在普通 Markdown 阅读器中无法正常显示？

Gits Reader 为此而生。我们砍掉了所有编辑入口，采用“纯净只读”的设计理念，配合极速浅克隆技术与 Claude 级沉浸式美学排版，彻底解决您在移动端轻量查阅笔记的痛点。

【核心特性】

1. 零冲突，纯净只读
- 界面不提供任何编辑入口，从根本上杜绝多端同步时的合并冲突风险。
- 放心阅读，无需担心误触修改或损坏您的核心知识库。

2. 极速 Git 同步
- 采用浅克隆（Shallow Clone，仅拉取 HEAD）技术，秒级完成万级笔记的同步。
- App 启动自动 Pull，支持目录页下拉刷新与手动同步，随时保持内容最新。
- 个人访问令牌（PAT）通过 iOS Keychain 安全存储，保障您的隐私与数据安全。

3. 完美的 Obsidian 语法原生渲染
- 完美支持 `[[笔记名]]` 与 `[[笔记名|别名]]` 双链语法，点击即可流畅跳转（Push 导航）。
- 智能路径修复，本地图片无缝秒开，无需任何手动配置。
- 优雅的折叠式 Frontmatter 卡片，默认收起，点击展开完整 YAML 键值对。

4. Claude 级沉浸式美学
- 借鉴 Claude 的美学设计，主背景采用温暖细腻的米白与深邃炭黑（完美支持暗黑模式）。
- 正文首选系统 Serif 衬线字体，严格控制字间距与行高（1.6倍），提供极佳的长文阅读舒适度。
- 无阴影、微圆角、细边框的扁平卡片样式，通过优雅的留白划分视觉层级。

5. 离线可用
- 自动缓存上次同步的数据，在地铁、飞机等无信号环境下自动切换为“离线模式”，阅读不中断。

6. 智能搜索
- 支持文件名与 Frontmatter 字段（title/tags/aliases）的快速检索，瞬间定位目标笔记。

【适用人群】
- 使用 Obsidian + Git 管理个人知识库（PKM）的学者、开发者、写作爱好者。
- 需要在移动端高频查阅、复习笔记，但不需要在手机上进行重度编辑的用户。
- 追求极致排版与沉浸式阅读体验的美学主义者。

Gits Reader，让您的知识库随身携带，温润、纯净、安全。

注：Gits Reader 是一款独立应用，与 Obsidian、GitHub、GitLab 无任何官方关联。Obsidian 为 Obsidian MD Ltd 的注册商标，GitHub 为 GitHub, Inc. 的注册商标，GitLab 为 GitLab Inc. 的注册商标。
```

---

## 4. 隐私政策与支持 (Privacy & Support)

* **隐私政策 URL (Privacy Policy URL)**: (必填，见同目录下的 `privacy.html` 部署指南)
* **技术支持 URL (Support URL)**: (必填，可以使用您的 GitHub 仓库 Issues 页面，例如：`https://github.com/您的用户名/git-reader/issues`)
