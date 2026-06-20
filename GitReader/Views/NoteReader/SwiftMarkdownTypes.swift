import Markdown

// Re-export swift-markdown types with disambiguating names
// This file exists because swift-markdown and MarkdownUI both define
// types with the same names (Heading, Text, etc.)
typealias SwiftMarkdownDocument = Markdown.Document
typealias SwiftMarkdownMarkup = Markup
typealias SwiftMarkdownHeading = Heading
typealias SwiftMarkdownParagraph = Paragraph
typealias SwiftMarkdownUnorderedList = UnorderedList
typealias SwiftMarkdownOrderedList = OrderedList
typealias SwiftMarkdownCodeBlock = CodeBlock
typealias SwiftMarkdownText = Markdown.Text
typealias SwiftMarkdownEmphasis = Emphasis
typealias SwiftMarkdownStrong = Strong
typealias SwiftMarkdownLink = Markdown.Link
typealias SwiftMarkdownInlineCode = InlineCode
typealias SwiftMarkdownImage = Markdown.Image
typealias SwiftMarkdownBlockQuote = BlockQuote
typealias SwiftMarkdownTable = Table
typealias SwiftMarkdownThematicBreak = ThematicBreak
typealias SwiftMarkdownListItem = ListItem
