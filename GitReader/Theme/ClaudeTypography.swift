import SwiftUI

/// Claude 美学排版常量
enum ClaudeTypography {
    // 标题: 衬线体，加粗
    static let titleFont: Font = .system(.title, design: .serif).bold()
    static let largeTitleFont: Font = .system(.largeTitle, design: .serif).bold()

    // 正文: 衬线体，标准字重，行间距 6pt
    static let bodyFont: Font = .system(.body, design: .serif)
    static let bodyLineSpacing: CGFloat = 6

    // 代码: 等宽体
    static let codeFont: Font = .system(.body, design: .monospaced)
    static let codeCaptionFont: Font = .system(.caption, design: .monospaced)

    // 辅助文本
    static let captionFont: Font = .system(.caption, design: .serif)
    static let monoCaptionFont: Font = .system(.caption, design: .monospaced)

    // 卡片
    static let cardCornerRadius: CGFloat = 8
    static let cardPadding: CGFloat = 14
    static let cardBorderWidth: CGFloat = 1

    // 阅读页
    static let readerHorizontalPadding: CGFloat = 20
    static let readerContentSpacing: CGFloat = 20

    // 导航栏
    static let navBarHeight: CGFloat = 50
    static let navTitleFont: Font = .system(.headline, design: .serif)
}
