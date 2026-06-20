import Foundation
import Markdown

/// 将 swift-markdown AST 块级节点分类为 BlockElement，驱动 SwiftUI 渲染分发。
/// 纯函数无副作用，便于单元测试。
public enum MarkdownBlockClassifier {

    /// 分类顶层块元素
    public static func classify(_ markup: Markup) -> BlockElement {
        switch markup {
        case let heading as Heading:
            return .heading(level: heading.level, text: extractText(heading))

        case is Paragraph:
            return .paragraph

        case let list as UnorderedList:
            return .unorderedList(depth: listDepth(list))

        case let list as OrderedList:
            return .orderedList(depth: listDepth(list))

        case let codeBlock as CodeBlock:
            let lang = codeBlock.language?.lowercased() ?? ""
            return .codeBlock(CodeBlockData(
                code: codeBlock.code,
                language: lang.isEmpty ? "plaintext" : lang
            ))

        case let blockquote as BlockQuote:
            let children = blockquote.children.map { classify($0) }
            return .blockquote(children: children)

        case let table as Table:
            return .table(extractTable(table))

        case is ThematicBreak:
            return .thematicBreak

        default:
            return .unknown
        }
    }

    /// 计算 Markdown 列表的嵌套深度（0 = 顶层列表）
    public static func listDepth(_ markup: Markup) -> Int {
        var depth = 0
        var current: Markup? = markup.parent

        while let parent = current {
            if parent is UnorderedList || parent is OrderedList {
                depth += 1
            }
            current = parent.parent
        }

        return depth
    }

    /// 从 Table 提取表头和行数据
    public static func extractTable(_ table: Table) -> TableData {
        let headers = table.head.children.compactMap { $0 as? Table.Cell }.map { extractText($0) }

        var rows: [[String]] = []
        for row in table.body.children {
            guard let tableRow = row as? Table.Row else { continue }
            let cells = tableRow.children.compactMap { $0 as? Table.Cell }.map { extractText($0) }
            rows.append(cells)
        }

        return TableData(headers: headers, rows: rows)
    }

    /// 递归提取 Markup 中所有 Text 的纯文本
    private static func extractText(_ markup: Markup) -> String {
        var result = ""
        for child in markup.children {
            if let text = child as? Text {
                result += text.string
            } else {
                result += extractText(child)
            }
        }
        return result
    }
}
