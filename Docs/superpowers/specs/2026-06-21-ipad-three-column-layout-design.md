# iPad 三栏收起展开适配方案设计文档 (Spec)

* **日期**：2026-06-21
* **作者**：GitReader AI Agent
* **状态**：已批准 (Approved)

---

## 1. 概述 (Overview)

本项目在 iPad / macOS 设备的常规尺寸（regular size class）下采用三栏布局：
1. **最左侧仓库栏** (`SidebarView`)：宽度为 80 的自定义视图，用于切换 Git 仓库、管理账户以及打开设置。
2. **中部目录栏** (`FileListView`)：`NavigationSplitView` 的 sidebar 列，展示文件目录树。
3. **右侧阅读区** (`NoteReaderView`)：`NavigationSplitView` 的 detail 列，展示 Markdown 笔记内容。

经过多次迭代与优化，我们最终确定了最符合原生 iPadOS 体验、最简洁且无 Bug 的设计：
* **最左侧仓库栏**：作为全局导航和切换的核心，在 iPad 上**始终保持可见**，不参与收起/展开。
* **中部目录栏**：支持通过原生的侧边栏切换按钮进行收起与展开，进入沉浸式阅读状态。
* **设置按钮**：从目录栏顶部移至最左侧仓库栏的底部，留出底部安全区域，在 iPhone 和 iPad 上保持高度一致。

---

## 2. 核心交互与布局逻辑 (Core Interaction & Layout)

### 2.1 布局结构
采用标准的 `HStack` 嵌套 `NavigationSplitView`：
```swift
HStack(spacing: 0) {
    // 1. 最左侧仓库栏（始终可见）
    SidebarView(...)
    
    Divider()
    
    // 2. 右侧标准的双栏 NavigationSplitView
    NavigationSplitView(columnVisibility: $columnVisibility) {
        FileListView(...) // 中部目录栏（可收起）
    } detail: {
        NoteReaderView(...) // 右侧阅读区
    }
}
```

### 2.2 状态定义与转换

| 布局状态 | 仓库栏 (`SidebarView`) | 目录栏 (`FileListView`) | 触发方式 |
| :--- | :---: | :---: | :--- |
| **状态 1：全展开** | 始终显示 | 显示 (`.doubleColumn` / `.automatic`) | 默认状态 |
| **状态 2：沉浸式阅读** | 始终显示 | 隐藏 (`.detailOnly`) | 点击阅读区左上角原生的侧边栏切换按钮 |

---

## 3. 技术实现方案 (Technical Implementation)

### 3.1 状态管理简化
由于去除了复杂的渐进式多级收起状态，我们**完全删除了自定义的 `LayoutManager.swift`**，回归到最纯粹、最原生的 SwiftUI 状态管理：
* 在 `MainContainerView.swift` 中定义 `@State private var columnVisibility: NavigationSplitViewVisibility = .automatic`。
* 直接绑定到 `NavigationSplitView(columnVisibility: $columnVisibility)`。

### 3.2 视图层改造

#### 1. `MainContainerView.swift`
* 移除了 `LayoutManager` 相关的 `@StateObject`。
* 引入 `@State private var columnVisibility` 和 `@State private var showSettingsSheet`。
* 使用标准的 `HStack` 布局，将 `SidebarView` 和 `NavigationSplitView` 并排排列。
* 移除了 `.toolbar(removing: .sidebarToggle)`，恢复原生的侧边栏切换按钮。
* 在主容器底部挂载设置弹窗：
  ```swift
  .sheet(isPresented: $showSettingsSheet) {
      NavigationStack {
          SettingsView(hasConfiguredRepo: $hasConfiguredRepo)
      }
  }
  ```

#### 2. `SidebarView.swift`
* 引入 `@Binding var showSettingsSheet: Bool`。
* 在 `VStack` 底部（`Spacer()` 之后）添加了设置按钮（齿轮图标 `gearshape`）。
* 添加了 `.padding(.bottom, 16)` 留出底部安全区域，完美适配 iPhone 的 Home Indicator 和 iPad 的底部留白。

#### 3. `FileListView.swift`
* 彻底移除了旧的设置按钮、旧的 `showSettingsSheet` 状态以及旧的 `.sheet` 弹窗修饰符，保持目录栏顶部的纯粹。

#### 4. `NoteReaderView.swift`
* 彻底移除了之前添加的自定义统一控制按钮，完全由系统原生的侧边栏切换按钮接管目录栏的收起与展开。

---

## 4. 验证与测试计划 (Verification & Testing)

1. **编译验证**：运行 `xcodegen generate` 重新生成项目，确保项目在 iPad 模拟器上编译无误。
2. **交互验证**：
   * 启动应用，最左侧仓库栏始终显示在最左侧。
   * 点击阅读区左上角原生的侧边栏切换按钮，中部目录栏应平滑收起，进入沉浸式阅读状态。
   * 再次点击该按钮，中部目录栏应平滑展开。
   * 点击最左侧侧边栏底部的设置按钮，应平滑弹出卡片式设置页，点击“完成”后正常关闭，且不影响任何阅读状态。
