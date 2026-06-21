import Foundation
import Highlightr
#if canImport(UIKit)
import UIKit
#endif

/// 代码高亮主题（与 SwiftUI ColorScheme 解耦）
enum CodeHighlightTheme {
    case light
    case dark
}

/// 代码高亮协议（便于测试和替换实现）
protocol CodeHighlighting {
    func highlight(code: String, language: String, theme: CodeHighlightTheme) -> AttributedString
}

/// 基于 Highlightr（highlight.js）的代码高亮实现
final class HighlightrCodeHighlighter: CodeHighlighting {
    private let darkHighlighter: Highlightr?
    private let lightHighlighter: Highlightr?

    init() {
        self.darkHighlighter = Highlightr()
        self.lightHighlighter = Highlightr()
        darkHighlighter?.setTheme(to: "pojoaque")
        lightHighlighter?.setTheme(to: "xcode")
    }

    func highlight(code: String, language: String, theme: CodeHighlightTheme) -> AttributedString {
        let normalized = LanguageNormalizer.normalize(language)
        let highlighter = theme == .dark ? darkHighlighter : lightHighlighter

        guard let highlighter = highlighter,
              let highlighted = highlighter.highlight(code, as: normalized, fastRender: true) else {
            return AttributedString(code)
        }

        return AttributedString(highlighted)
    }
}
