import Foundation

/// 将代码块语言别名规范化为 Highlightr 支持的标准语言名。
/// 纯函数无副作用，便于单元测试。
public enum LanguageNormalizer {

    /// 语言别名 → Highlightr 支持语言名的映射表（key 已小写）
    private static let aliases: [String: String] = [
        "swift": "swift",
        "ts": "typescript",
        "typescript": "typescript",
        "js": "javascript",
        "javascript": "javascript",
        "jsx": "javascript",
        "tsx": "typescript",
        "py": "python",
        "python": "python",
        "rb": "ruby",
        "ruby": "ruby",
        "sh": "bash",
        "shell": "bash",
        "bash": "bash",
        "zsh": "bash",
        "yml": "yaml",
        "yaml": "yaml",
        "c": "c",
        "c++": "cpp",
        "cpp": "cpp",
        "c#": "csharp",
        "cs": "csharp",
        "csharp": "csharp",
        "objc": "objectivec",
        "obj-c": "objectivec",
        "objectivec": "objectivec",
        "kt": "kotlin",
        "kotlin": "kotlin",
        "rs": "rust",
        "rust": "rust",
        "go": "go",
        "golang": "go",
        "java": "java",
        "dart": "dart",
        "scala": "scala",
        "lua": "lua",
        "r": "r",
        "sql": "sql",
        "php": "php",
        "html": "xml",
        "xml": "xml",
        "css": "css",
        "json": "json",
        "markdown": "markdown",
        "md": "markdown",
        "plaintext": "plaintext",
        "text": "plaintext",
        "txt": "plaintext",
    ]

    /// 将语言别名规范化为 Highlightr 支持的语言名
    public static func normalize(_ raw: String?) -> String {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "plaintext"
        }
        let lowercased = raw.lowercased()
        return aliases[lowercased] ?? "plaintext"
    }
}
