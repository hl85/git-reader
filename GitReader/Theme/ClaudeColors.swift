import SwiftUI

/// Claude 美学色彩系统
/// Light: 温暖米白底 + 极淡灰边框
/// Dark: 深邃炭黑底 + 微亮分割线
enum ClaudeColors {
    // Light mode
    static let lightBackground    = Color(red: 0.984, green: 0.984, blue: 0.980) // #FBFBFA
    static let lightCardBackground = Color(red: 0.961, green: 0.961, blue: 0.949) // #F5F5F2
    static let lightBorder        = Color(red: 0.898, green: 0.898, blue: 0.878) // #E5E5E0
    static let lightBorderStrong  = Color(red: 0.835, green: 0.835, blue: 0.808) // #D5D5CE
    static let lightText          = Color(red: 0.102, green: 0.102, blue: 0.102) // #1A1A1A
    static let lightTextSecondary = Color(red: 0.478, green: 0.478, blue: 0.455) // #7A7A74
    static let lightTextMuted     = Color(red: 0.690, green: 0.690, blue: 0.667) // #B0B0AA
    static let lightLink          = Color(red: 0.357, green: 0.498, blue: 0.647) // #5B7FA5
    static let lightTagBackground = Color(red: 0.929, green: 0.929, blue: 0.910) // #EDEDE8
    static let lightTagText       = Color(red: 0.416, green: 0.416, blue: 0.392) // #6A6A64
    static let lightAccent        = Color(red: 0.851, green: 0.467, blue: 0.341) // #D97757

    // Dark mode
    static let darkBackground     = Color(red: 0.102, green: 0.102, blue: 0.102)
    static let darkCardBackground = Color(red: 0.141, green: 0.141, blue: 0.133)
    static let darkBorder         = Color(red: 0.200, green: 0.200, blue: 0.188)
    static let darkBorderStrong   = Color(red: 0.267, green: 0.267, blue: 0.251)
    static let darkText           = Color(red: 0.910, green: 0.910, blue: 0.894)
    static let darkTextSecondary  = Color(red: 0.565, green: 0.565, blue: 0.541)
    static let darkTextMuted      = Color(red: 0.376, green: 0.376, blue: 0.353)
    static let darkLink           = Color(red: 0.502, green: 0.667, blue: 0.792)
    static let darkTagBackground  = Color(red: 0.165, green: 0.165, blue: 0.157)
    static let darkTagText        = Color(red: 0.627, green: 0.627, blue: 0.604)
    static let darkAccent         = Color(red: 0.878, green: 0.541, blue: 0.416)

    // Semantic aliases
    static var background: Color {
        Color(lightScheme: lightBackground, darkScheme: darkBackground)
    }
    static var cardBackground: Color {
        Color(lightScheme: lightCardBackground, darkScheme: darkCardBackground)
    }
    static var border: Color {
        Color(lightScheme: lightBorder, darkScheme: darkBorder)
    }
    static var borderStrong: Color {
        Color(lightScheme: lightBorderStrong, darkScheme: darkBorderStrong)
    }
    static var text: Color {
        Color(lightScheme: lightText, darkScheme: darkText)
    }
    static var textSecondary: Color {
        Color(lightScheme: lightTextSecondary, darkScheme: darkTextSecondary)
    }
    static var textMuted: Color {
        Color(lightScheme: lightTextMuted, darkScheme: darkTextMuted)
    }
    static var link: Color {
        Color(lightScheme: lightLink, darkScheme: darkLink)
    }
    static var tagBackground: Color {
        Color(lightScheme: lightTagBackground, darkScheme: darkTagBackground)
    }
    static var tagText: Color {
        Color(lightScheme: lightTagText, darkScheme: darkTagText)
    }
    static var accent: Color {
        Color(lightScheme: lightAccent, darkScheme: darkAccent)
    }
}

extension Color {
    init(lightScheme: Color, darkScheme: Color) {
        self.init(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(darkScheme)
                : UIColor(lightScheme)
        })
    }
}
