# 详情页实用功能设计文档 (2026-06-18)

## 1. 需求概述
在笔记阅读详情页（`NoteReaderView`）中增加以下实用功能：
1. **文本选择与拷贝**：支持按住拖动选择文本，并弹出系统原生的拷贝选项。
2. **更多操作菜单**：在右上角导航栏增加 `•••` 按钮，点击弹出菜单，包含：
   - **设置属性标签**：编辑当前笔记的 tags。
   - **拷贝全文文本**：一键拷贝 Markdown 源码。
   - **保存整页长图**：将整篇笔记渲染为一张完整的图片并分享/保存。
   - **导出为 PDF**：将整篇笔记渲染并生成标准的 PDF 文件并分享/保存。

---

## 2. 技术方案设计

### 2.1 文本选择与拷贝
* **方案**：在 `NoteReaderView` 的主容器（如 `ScrollView` 或 `VStack`）上应用 `.textSelection(.enabled)`。
* **原理**：SwiftUI 3.0+ 提供的原生修饰符，能自动使容器内所有的 `Text` 视图支持原生选择、双端滑块、放大镜以及拷贝气泡，完全免去手势冲突。

### 2.2 右上角 `•••` 更多菜单
* **方案**：在 `NoteReaderView` 的 `.toolbar` 中增加一个 `ToolbarItem`，使用 `Menu` 控件展示。
* **代码结构**：
  ```swift
  ToolbarItem(placement: .navigationBarTrailing) {
      Menu {
          Button(action: showSetTagsSheet) {
              Label("设置属性标签", systemImage: "tag")
          }
          Button(action: copyFullText) {
              Label("拷贝全文文本", systemImage: "doc.on.doc")
          }
          Button(action: captureLongScreenshot) {
              Label("保存整页长图", systemImage: "photo")
          }
          Button(action: exportToPDF) {
              Label("导出为 PDF", systemImage: "doc.plaintext")
          }
      } label: {
          Image(systemName: "ellipsis.circle")
              .font(.system(size: 16))
              .foregroundStyle(ClaudeColors.textSecondary)
      }
  }
  ```

### 2.3 设置属性标签 (SetTagsSheet)
* **方案**：点击后弹出半屏 Sheet，展示当前笔记的所有标签，并允许用户添加、删除标签。
* **保存逻辑**：
  1. 用户编辑完标签并点击保存。
  2. 读取本地 Markdown 文件，解析 Frontmatter。
  3. 更新 Frontmatter 中的 `tags` 字段。
  4. 将更新后的 Frontmatter 和 Markdown 正文重新写入本地文件。
  5. 触发 `loadNote()` 重新加载当前笔记，并通知主界面刷新文件列表。

### 2.4 拷贝全文文本
* **方案**：直接将 `markdownString` 写入系统剪贴板：
  ```swift
  UIPasteboard.general.string = markdownString
  toastMessage = "全文已拷贝到剪贴板"
  showToast = true
  ```

### 2.5 保存整页长图与导出 PDF (核心难点)
* **方案**：**离屏渲染（Offscreen Rendering）**。
* **原理**：
  1. 创建一个离屏的 `UIHostingController`，其 `rootView` 为一个专门用于导出的干净视图 `ExportContentView`（包含标题、Frontmatter 卡片和 Markdown 正文，去除导航栏和背景遮罩）。
  2. 强制该控制器在后台进行完整布局，计算出内容所需的真实高度：
     ```swift
     let targetSize = CGSize(width: UIScreen.main.bounds.width, height: UIView.layoutFittingCompressedSize.height)
     let size = hostingController.view.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
     hostingController.view.frame = CGRect(origin: .zero, size: size)
     ```
  3. **长图导出**：使用 `UIGraphicsImageRenderer` 将该控制器的 view 绘制为一张超长 `UIImage`：
     ```swift
     let renderer = UIGraphicsImageRenderer(size: size)
     let image = renderer.image { context in
         hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
     }
     ```
  4. **PDF 导出**：使用 `UIGraphicsPDFRenderer` 将内容绘制到 PDF 上下文中，生成 `.pdf` 文件。
  5. **分享/保存**：使用 `UIActivityViewController`（系统分享框）让用户自由选择“保存到相册”、“保存到文件”或发送给朋友。

---

## 3. 影响评估
* **性能影响**：离屏渲染长图和 PDF 会在后台线程进行布局和绘制，对主线程卡顿影响极小。对于超长文本，绘制可能需要 1-2 秒，期间会展示 Loading 提示。
* **文件写入安全**：更新标签时会重新写入本地文件，需确保写入操作在后台线程进行，避免阻塞主线程。

---

## 4. 验证计划
1. **文本选择测试**：长按正文，验证是否能正常唤起原生选择滑块和拷贝气泡。
2. **标签编辑测试**：修改标签并保存，验证本地 Markdown 文件的 Frontmatter 是否正确更新，且阅读页和主页列表是否同步刷新。
3. **长图导出测试**：点击“保存整页长图”，验证生成的图片是否完整（包含未显示在屏幕上的部分），且能正常保存到相册。
4. **PDF 导出测试**：点击“导出为 PDF”，验证生成的 PDF 文件是否排版正确，且能正常保存到文件。
