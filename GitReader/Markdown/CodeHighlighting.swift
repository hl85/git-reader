import Foundation
import Highlightr
#if canImport(UIKit)
import UIKit
#endif

/// 代码高亮协议（便于测试和替换实现）
protocol CodeHighlighting {
    func highlight(code: String, language: String) -> AttributedString
}

/// 基于 Highlightr（highlight.js）的代码高亮实现
final class HighlightrCodeHighlighter: CodeHighlighting {
    private let highlightr: Highlightr?

    init() {
        self.highlightr = Highlightr()
        highlightr?.setTheme(to: "pojoaque")
    }

    func highlight(code: String, language: String) -> AttributedString {
        let normalized = LanguageNormalizer.normalize(language)

        guard let highlightr = highlightr,
              let highlighted = highlightr.highlight(code, as: normalized, fastRender: true) else {
            return AttributedString(code)
        }

        return AttributedString(highlighted)
    }
}
