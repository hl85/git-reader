import Foundation

/// 文件扫描服务：遍历沙盒目录，构建文件夹树
final class FileScannerService: @unchecked Sendable {
    static let shared = FileScannerService()

    private let fileManager = FileManager.default
    private let repoRoot: URL

    /// 最大扫描深度（防止深层嵌套）
    private let maxDepth = 5

    /// 排除的目录名
    private let excludedDirs: Set<String> = [
        ".git", ".obsidian", ".trash", "node_modules", ".DS_Store"
    ]

    private let lock = NSLock()
    private var cachedNoteIndex: [String: URL]?

    private init() {
        self.repoRoot = GitSyncService.shared.repoRootURL
    }

    /// 扫描并构建目录树
    /// - Returns: 文件夹节点列表
    func scanDirectory() -> [FolderNode] {
        guard fileManager.fileExists(atPath: repoRoot.path) else {
            return []
        }
        return scanDirectory(at: repoRoot, depth: 0)
    }

    /// 获取所有 .md 文件的完整路径列表（扁平化）
    func getAllMarkdownFiles() -> [URL] {
        var files: [URL] = []
        collectMarkdownFiles(at: repoRoot, into: &files)
        return files
    }

    /// 在文件树中根据笔记名查找文件 URL
    /// - Parameter noteName: WikiLinks 中的目标笔记名（大小写不敏感，支持路径型 [[folder/note]]）
    /// - Returns: 匹配的 .md 文件 URL，未找到返回 nil
    func findNote(named noteName: String) -> URL? {
        let cleanNoteName = noteName.trimmingCharacters(in: .whitespaces)
        guard !cleanNoteName.isEmpty else { return nil }
        let lowercasedNoteName = cleanNoteName.lowercased()

        // 1. 优先从内存缓存中读取
        lock.lock()
        if let cached = cachedNoteIndex {
            if let match = cached[lowercasedNoteName] {
                lock.unlock()
                return match
            }
            // 如果缓存中没有，且输入是路径型，尝试取最后一段匹配
            let lastComponent = cleanNoteName.components(separatedBy: "/").last?.trimmingCharacters(in: .whitespaces) ?? ""
            if !lastComponent.isEmpty, let match = cached[lastComponent.lowercased()] {
                lock.unlock()
                return match
            }
            lock.unlock()
            return nil
        }
        lock.unlock()

        // 2. 缓存未命中或未建立时，回退到全盘扫描（兼容未初始化状态）
        let allFiles = getAllMarkdownFiles()

        // 2.1 优先尝试完整相对路径匹配 (e.g., "folder/note")
        if let match = allFiles.first(where: { file in
            let relativePath = file.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
            let notePath = (relativePath as NSString).deletingPathExtension
            return notePath.lowercased() == lowercasedNoteName
        }) {
            return match
        }

        // 2.2 退化为匹配最后一段文件名 (e.g., "note")
        let lastComponent = cleanNoteName.components(separatedBy: "/").last?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !lastComponent.isEmpty else { return nil }
        let lowercasedLast = lastComponent.lowercased()

        return allFiles.first { file in
            let filename = file.deletingPathExtension().lastPathComponent
            return filename.lowercased() == lowercasedLast
        }
    }

    /// 构建 [笔记名: 文件路径] 字典，用于 WikiLinks 路由
    func buildNoteIndex() -> [String: URL] {
        lock.lock()
        defer { lock.unlock() }

        let files = getAllMarkdownFiles()
        var index: [String: URL] = [:]
        for file in files {
            // 1. 存入文件名作为 Key (e.g., "note")
            let filename = file.deletingPathExtension().lastPathComponent
            index[filename.lowercased()] = file

            // 2. 存入完整相对路径作为 Key (e.g., "folder/note")
            let relativePath = file.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
            let notePath = (relativePath as NSString).deletingPathExtension
            index[notePath.lowercased()] = file
        }
        self.cachedNoteIndex = index
        return index
    }

    // MARK: - Private

    private func scanDirectory(at url: URL, depth: Int) -> [FolderNode] {
        guard depth < maxDepth else { return [] }

        var folders: [FolderNode] = []
        var rootFiles: [FileItem] = []

        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let sorted = contents.sorted { $0.lastPathComponent < $1.lastPathComponent }

        for itemURL in sorted {
            let name = itemURL.lastPathComponent

            // 跳过排除目录
            if excludedDirs.contains(name) { continue }

            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir) else {
                continue
            }

            if isDir.boolValue {
                // 子文件夹
                let children = scanDirectory(at: itemURL, depth: depth + 1)
                    .flatMap { $0.children }
                // 只保留 .md 文件
                let mdChildren = children.filter { $0.url.pathExtension == "md" }
                if !mdChildren.isEmpty {
                    let folder = FolderNode(name: name, children: mdChildren)
                    folders.append(folder)
                }
            } else if name.hasSuffix(".md") {
                // .md 文件
                let metadata = extractMetadata(from: itemURL)
                let fileItem = FileItem(
                    name: itemURL.deletingPathExtension().lastPathComponent,
                    url: itemURL,
                    isDirectory: false,
                    tags: metadata.tags,
                    status: metadata.status
                )
                rootFiles.append(fileItem)
            }
        }

        // 根目录下的 .md 文件不打入文件夹
        if !rootFiles.isEmpty {
            let rootFolder = FolderNode(name: "root_directory".localized, children: rootFiles)
            folders.insert(rootFolder, at: 0)
        }

        return folders
    }

    /// 高速文本扫描提取 Frontmatter 中的 tags 和 status
    func extractMetadata(from fileURL: URL) -> (tags: [String], status: String?) {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return ([], nil)
        }
        
        // 仅读取前 50 行，避免读取超大文件导致性能损耗
        let lines = content.components(separatedBy: .newlines).prefix(50)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return ([], nil)
        }
        
        var tags: [String] = []
        var status: String? = nil
        var parsingTagsList = false
        
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                break
            }
            
            if trimmed.hasPrefix("status:") {
                parsingTagsList = false
                let val = trimmed.dropFirst("status:".count).trimmingCharacters(in: .whitespaces)
                status = val.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            } else if trimmed.hasPrefix("tags:") {
                let val = trimmed.dropFirst("tags:".count).trimmingCharacters(in: .whitespaces)
                if val.hasPrefix("[") && val.hasSuffix("]") {
                    parsingTagsList = false
                    let tagsContent = val.dropFirst().dropLast()
                    tags = tagsContent.components(separatedBy: ",").map {
                        $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    }.filter { !$0.isEmpty }
                } else if !val.isEmpty {
                    parsingTagsList = false
                    tags = [val.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))]
                } else {
                    parsingTagsList = true
                }
            } else if parsingTagsList && trimmed.hasPrefix("-") {
                let val = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                if !val.isEmpty {
                    tags.append(val.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")))
                }
            } else {
                parsingTagsList = false
            }
        }
        
        return (tags, status)
    }

    private func collectMarkdownFiles(at url: URL, into result: inout [URL]) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for itemURL in contents {
            let name = itemURL.lastPathComponent
            if excludedDirs.contains(name) { continue }

            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir) else {
                continue
            }

            if isDir.boolValue {
                collectMarkdownFiles(at: itemURL, into: &result)
            } else if name.hasSuffix(".md") {
                result.append(itemURL)
            }
        }
    }
}
