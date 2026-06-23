# 仓库级状态流转及属性规范设计文档 (Repository-level Template Spec)

本文档描述了如何在 GitsReader 中实现仓库级状态流转及属性规范。当仓库中存在特定的配置文件时，App 将动态替换默认的属性模板和状态流转规则，实现高度定制化的元数据管理。

---

## 1. 需求背景与目标

目前 GitsReader 采用全局唯一的属性模板（由 `PropertyTemplateManager` 管理，存储于 `UserDefaults`）。这使得所有 Git 仓库都必须共享同一套 Frontmatter 属性字段和状态选项。

为了支持多仓库的个性化管理（例如：工作仓库需要 `todo/in-progress/done` 状态，而读书笔记仓库需要 `reading/archived` 状态），我们需要支持**仓库级属性规范**：
*   **零根目录污染**：配置文件放置在 `.obsidian/gitsreader.yaml`。
*   **动态响应式替换**：切换仓库或同步完成后，属性编辑界面自动刷新为当前仓库的专属模板。
*   **完美向下兼容**：若仓库未配置该文件，自动回退到用户自定义的全局默认模板。

---

## 2. 配置文件规范 (`.obsidian/gr-workflow.yaml`)

配置文件采用标准 YAML 格式，声明该仓库支持的 Frontmatter 字段、类型及可选项。

### 示例配置
```yaml
- name: date
  type: date
- name: status
  type: enum
  options: [backlog, in-progress, review, done]
- name: tags
  type: tags
- name: priority
  type: enum
  options: [high, medium, low]
- name: assignee
  type: text
```

### 字段类型约束 (`FieldType`)
*   `date`：日期类型，在属性编辑页渲染为日期选择器。
*   `enum`：单选枚举类型，必须提供 `options` 数组，在属性编辑页渲染为单选列表。
*   `tags`：标签数组类型，在属性编辑页渲染为标签输入与多选。
*   `text`：单行文本类型，在属性编辑页渲染为文本输入框。

---

## 3. 架构设计 (Architecture & Data Flow)

我们采用**动态单例代理模式**。外部 UI 视图无需感知模板来自全局还是仓库级，统一通过 `PropertyTemplateManager.shared.fields` 读取。

```
+-----------------------------------------------------------------+
|                     PropertyTemplateManager                     |
|                                                                 |
|  +------------------+  No   +--------------------------------+  |
|  | activeRepository | ----> | Read Global UserDefaults YAML  |  |
|  +------------------+       +--------------------------------+  |
|           | Yes                                                 |
|           v                                                     |
|  +----------------------------------+                           |
|  | Read .obsidian/gitsreader.yaml   |                           |
|  +----------------------------------+                           |
|           | Success                                             |
|           +------------------------+                            |
|           | Yes                    | No                         |
|           v                        v                            |
|  +------------------+    +-----------------------------------+  |
|  | Use Repo Fields  |    | Fallback to Global Fields         |  |
|  +------------------+    +-----------------------------------+  |
|           |                        |                            |
|           +-----------+------------+                            |
|                       |                                         |
|                       v                                         |
|             @Published var fields                               |
+-----------------------------------------------------------------+
                        |
                        v (Reactive Update)
             +---------------------+
             |  SwiftUI UI Views   |
             +---------------------+
```

### 3.1 核心触发源 (Trigger Events)
属性模板的重新加载由以下两个事件触发：
1.  **切换激活仓库**：监听 `NotificationCenter.default.publisher(for: .activeRepositoryDidChange)`。
2.  **Git 同步完成**：监听 `NotificationCenter.default.publisher(for: .gitSyncDidComplete)`（新增通知，在 `sync()` 或 `clone()` 成功后发送，因为同步可能会拉取到最新的 `.obsidian/gitsreader.yaml` 配置文件）。

---

## 4. 关键代码改动设计

### 4.1 新增通知定义
在 `Notification.Name` 扩展中新增：
```swift
extension Notification.Name {
    static let gitSyncDidComplete = Notification.Name("gitSyncDidComplete")
}
```
并在 `GitSyncService.swift` 的 `sync()` 和 `clone()` 成功处发送该通知。

### 4.2 `PropertyTemplateManager` 升级
重构 `PropertyTemplateManager`，使其支持动态加载和缓存：

```swift
@MainActor
class PropertyTemplateManager: ObservableObject {
    @MainActor static let shared = PropertyTemplateManager()
    
    // 全局默认/自定义 YAML 模板（UserDefaults 持久化）
    @Published var templateYAML: String {
        didSet {
            UserDefaults.standard.set(templateYAML, forKey: "PropertyTemplateYAML")
            if GitSyncService.shared.activeRepositoryID == nil {
                parseGlobalTemplate()
            }
        }
    }
    
    // 暴露给外部 UI 的响应式字段列表
    @Published private(set) var fields: [PropertyField] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 1. 初始化全局默认模板
        let defaultYAML = """
        - name: date
          type: date
        - name: status
          type: enum
          options: [idea, draft, review, reading, archived]
        - name: tags
          type: tags
        """
        self.templateYAML = UserDefaults.standard.string(forKey: "PropertyTemplateYAML") ?? defaultYAML
        
        // 2. 订阅仓库切换通知
        NotificationCenter.default.publisher(for: .activeRepositoryDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadTemplate()
            }
            .store(in: &cancellables)
            
        // 3. 订阅同步完成通知（配置文件可能被更新）
        NotificationCenter.default.publisher(for: .gitSyncDidComplete)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadTemplate()
            }
            .store(in: &cancellables)
            
        // 4. 首次加载
        reloadTemplate()
    }
    
    /// 核心加载方法：决策使用仓库级模板还是全局模板
    func reloadTemplate() {
        guard let activeRepo = GitSyncService.shared.activeRepository else {
            // 无激活仓库，使用全局模板
            parseGlobalTemplate()
            return
        }
        
        let repoRoot = GitSyncService.shared.repoRootURL
        let configFileURL = repoRoot
            .appendingPathComponent(".obsidian")
            .appendingPathComponent("gitsreader.yaml")
            
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            // 仓库未配置，回退到全局模板
            parseGlobalTemplate()
            return
        }
        
        // 尝试解析仓库级配置文件
        do {
            let yamlData = try String(contentsOf: configFileURL, encoding: .utf8)
            let decoder = YAMLDecoder()
            let repoFields = try decoder.decode([PropertyField].self, from: yamlData)
            self.fields = repoFields
            print("[PropertyTemplateManager] Successfully loaded repository-level template for: \(activeRepo.name)")
        } catch {
            print("[PropertyTemplateManager] Failed to parse repository-level template, falling back to global: \(error)")
            parseGlobalTemplate()
        }
    }
    
    private func parseGlobalTemplate() {
        do {
            let decoder = YAMLDecoder()
            self.fields = try decoder.decode([PropertyField].self, from: templateYAML)
        } catch {
            print("[PropertyTemplateManager] Failed to parse global template: \(error)")
            self.fields = []
        }
    }
}
```

---

## 5. 容错与边界处理

1.  **YAML 格式错误**：若 `.obsidian/gitsreader.yaml` 存在但格式损坏（如缩进错误、非法类型），App 不会崩溃，控制台打印错误日志，并**自动安全回退到全局默认模板**。
2.  **同步期间的模板更新**：当用户在电脑上修改了 `.obsidian/gitsreader.yaml` 并 push，手机端执行 `sync()` 拉取成功后，`gitSyncDidComplete` 通知会触发 `PropertyTemplateManager` 重新加载，属性编辑界面会**实时、无缝地刷新**为最新的字段和状态选项。
3.  **多仓库快速切换**：切换仓库时，`activeRepositoryDidChange` 通知会瞬间触发模板重载，保证用户在 A 仓库看到 A 的状态，在 B 仓库看到 B 的状态，实现完美的**多仓库隔离**。
