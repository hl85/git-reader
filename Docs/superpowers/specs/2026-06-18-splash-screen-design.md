# GitReader 闪屏动画设计文档 (Splash Screen Design Spec)

## 1. 视觉风格与创意设定

* **核心创意**：**书卷与墨水 (The Ink & Scroll)**
* **美学风格**：契合 Claude 的高知识感、沉浸式美学。
* **视觉表现**：
  * 极简的线条如墨水般绘制出 Git 分支（书脊），随后平滑展开成一本书的轮廓（书卷）。
  * 随后在书脊两端淡出 Git 节点圆点，下方优雅淡入 Serif 字体的 "GitReader" 标题。
* **色彩适配**：
  * **Light Mode**：背景采用细腻米白 (`#FBFBFA`)，书卷线条采用深色 (`#1A1A1A`)，书脊与节点采用橘红色 (`#D97757`)。
  * **Dark Mode**：背景采用深邃炭黑 (`#101010`)，书卷线条采用浅灰色 (`#E8E8E4`)，书脊与节点采用橘红色 (`#D97757`)。

---

## 2. 动画管线与时间轴 (Animation Timeline)

动画总时长控制在 **2.2 秒**，使用 SwiftUI 的原生 `Shape`、`trim(from:to:)` 以及 `withAnimation` 延时队列精确控制：

| 阶段 | 时间轴 | 视觉表现 | 技术实现 |
| :--- | :--- | :--- | :--- |
| **1. 墨水绘制 (Spine)** | 0.0s - 0.6s | 一条代表 Git 主分支的竖线从上至下绘制出来，使用橘红色 (`#D97757`)。 | `Path.addLine` + `trim(to: spineProgress)` |
| **2. 书卷展开 (Pages)** | 0.4s - 1.4s | 以竖线为书脊，左右两页书卷线条向外平滑展开，使用深色/浅色。 | `LeftPageShape` + `RightPageShape` + `trim` |
| **3. 节点与文字 (Fade In)** | 1.2s - 2.2s | 书脊上下两端淡出 Git 节点圆点，下方优雅淡入 Serif 字体 "GitReader" 标题。 | `opacity` + `offset(y)` + `scaleEffect` |

---

## 3. 状态管理与生命周期 (State & Lifecycle)

闪屏动画作为 App 的根视图包装器，控制主界面的加载。

### 3.1 包装器视图设计 (`SplashWrapperView`)
* 闪屏展示时间为 **2.5 秒**（2.2 秒动画 + 0.3 秒缓冲）。
* 结束后通过 `.opacity` 转换平滑淡出，无缝过渡到主界面 `AppRootView`。

### 3.2 核心代码结构
```swift
import SwiftUI

struct SplashWrapperView<Content: View>: View {
    @State private var isActive = false
    let content: () -> Content

    var body: some View {
        ZStack {
            if isActive {
                content()
                    .transition(.opacity.animation(.easeOut(duration: 0.5)))
            } else {
                SplashView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            isActive = true
                        }
                    }
            }
        }
    }
}
```

---

## 4. 视觉规范与性能保障

* **字体规范**：
  * 标题使用系统 Serif 字体（New York / Georgia），字重为 `.medium`。
  * 副标题使用系统 Sans-serif 字体（SF Pro），字重为 `.regular`，开启字母间距微调。
* **性能保障**：
  * 全矢量 SwiftUI 绘制，不使用任何外部图片或 Lottie 依赖。
  * 内存占用接近 0，确保在老旧 iOS 设备上也能丝滑运行。
  * 动画使用 `drawingGroup()` 硬件加速（如需要）。
