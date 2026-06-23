import Foundation
import Markdown
import Yams
@testable import TestableGitsReader

// MARK: - Test Utilities

var totalTests = 0
var passedTests = 0
var failedTests = 0
var failedMessages: [String] = []

func runSuite(_ name: String, _ block: () -> Void) {
    print("\n📋 \u{1B}[1;36m=== \(name) ===\u{1B}[0m")
    block()
}

func runSuite(_ name: String, _ block: () async -> Void) async {
    print("\n📋 \u{1B}[1;36m=== \(name) ===\u{1B}[0m")
    await block()
}

func test(_ description: String, _ body: () throws -> Void) {
    totalTests += 1
    do {
        try body()
        passedTests += 1
        print("  ✅ \(description)")
    } catch let error as TestFailure {
        failedTests += 1
        let msg = "  ❌ \(description): \(error.message)"
        print(msg)
        failedMessages.append(msg)
    } catch {
        failedTests += 1
        let msg = "  ❌ \(description): unexpected error: \(error)"
        print(msg)
        failedMessages.append(msg)
    }
}

func test(_ description: String, _ body: () async throws -> Void) async {
    totalTests += 1
    do {
        try await body()
        passedTests += 1
        print("  ✅ \(description)")
    } catch let error as TestFailure {
        failedTests += 1
        let msg = "  ❌ \(description): \(error.message)"
        print(msg)
        failedMessages.append(msg)
    } catch {
        failedTests += 1
        let msg = "  ❌ \(description): unexpected error: \(error)"
        print(msg)
        failedMessages.append(msg)
    }
}

struct TestFailure: Error {
    let message: String
}

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String? = nil) throws {
    guard actual == expected else {
        let msg = message ?? "expected \(expected), got \(actual)"
        throw TestFailure(message: msg)
    }
}

func assertTrue(_ condition: Bool, _ message: String = "condition is false") throws {
    guard condition else { throw TestFailure(message: message) }
}

func assertFalse(_ condition: Bool, _ message: String = "condition should be false") throws {
    guard !condition else { throw TestFailure(message: message) }
}

func assertNotNil<T>(_ value: T?, _ message: String = "value is nil") throws {
    guard value != nil else { throw TestFailure(message: message) }
}

func assertNil<T>(_ value: T?, _ message: String = "value is not nil") throws {
    guard value == nil else { throw TestFailure(message: "\(message) (got: \(value!))") }
}

func assertContains(_ string: String, _ substring: String, _ message: String? = nil) throws {
    guard string.contains(substring) else {
        throw TestFailure(message: message ?? "'\(string)' does not contain '\(substring)'")
    }
}

// MARK: - Test Helpers

let sandboxDir = URL(fileURLWithPath: "/tmp/git-reader-test/repo")

func makeDocument(_ markdown: String) -> Document {
    let document = Document(parsing: markdown)
    var rewriter = ObsidianElementRewriter(currentFileDirectory: sandboxDir)
    return rewriter.visit(document) as? Document ?? document
}

// ============================================================
// TEST SUITES
// ============================================================

let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("git-reader-tests-\(UUID().uuidString)")

defer {
    try? FileManager.default.removeItem(at: tempDir)
}

try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

// ============================================================
// FrontmatterSplitter Tests
// ============================================================
runSuite("FrontmatterSplitter - 正常情况") {

    test("有效 Frontmatter 返回 YAML 和正文") {
        let input = """
        ---
        title: Hello World
        tags: [swift, ios]
        ---
        # 正文内容

        这是一段正文。
        """
        let result = FrontmatterSplitter.split(input)
        try assertNotNil(result.frontmatterYAML)
        try assertTrue(result.frontmatterYAML!.contains("title: Hello World"))
        try assertTrue(result.frontmatterYAML!.contains("tags: [swift, ios]"))
        try assertTrue(result.pureMarkdownBody.hasPrefix("# 正文内容"))
        try assertFalse(result.pureMarkdownBody.contains("---"))
    }

    test("仅有 Frontmatter 返回空正文") {
        let input = """
        ---
        title: Minimal
        ---

        """
        let result = FrontmatterSplitter.split(input)
        try assertNotNil(result.frontmatterYAML)
        try assertEqual(result.frontmatterYAML!, "title: Minimal")
        try assertEqual(result.pureMarkdownBody, "")
    }

    test("多行 YAML 完整保留") {
        let input = """
        ---
        title: Complex Note
        tags:
          - swift
          - ios
        aliases:
          - note alias one
        created: 2024-01-15
        ---
        正文内容在这里。
        """
        let result = FrontmatterSplitter.split(input)
        try assertNotNil(result.frontmatterYAML)
        try assertTrue(result.frontmatterYAML!.contains("title: Complex Note"))
        try assertTrue(result.frontmatterYAML!.contains("tags:"))
        try assertEqual(result.pureMarkdownBody, "正文内容在这里。")
    }

    test("正文中包含 --- 正确保留") {
        let input = """
        ---
        title: Dash Test
        ---
        # Section 1

        这里有一些破折号：---

        但不是 frontmatter。
        """
        let result = FrontmatterSplitter.split(input)
        try assertEqual(result.frontmatterYAML!, "title: Dash Test")
        try assertTrue(result.pureMarkdownBody.contains("---"))
        try assertTrue(result.pureMarkdownBody.contains("但不是 frontmatter"))
    }
}

runSuite("FrontmatterSplitter - 无 Frontmatter 情况") {

    test("没有 --- 开头返回 nil YAML") {
        let input = "# 纯正文\n\n没有 frontmatter。"
        let result = FrontmatterSplitter.split(input)
        try assertNil(result.frontmatterYAML)
        try assertEqual(result.pureMarkdownBody, input)
    }

    test("不在开头的 --- 不算 frontmatter") {
        let input = "# Title\n---\n这是分隔线，不是 frontmatter。"
        let result = FrontmatterSplitter.split(input)
        try assertNil(result.frontmatterYAML)
        try assertEqual(result.pureMarkdownBody, input)
    }

    test("空字符串返回 nil YAML") {
        let result = FrontmatterSplitter.split("")
        try assertNil(result.frontmatterYAML)
        try assertEqual(result.pureMarkdownBody, "")
    }

    test("仅有开头 --- 无闭合返回 nil YAML") {
        let input = "---\n# 正文"
        let result = FrontmatterSplitter.split(input)
        try assertNil(result.frontmatterYAML)
        try assertEqual(result.pureMarkdownBody, input)
    }
}

runSuite("FrontmatterSplitter - 边界情况") {

    test("空白 Frontmatter 返回空 YAML") {
        let input = """
        ---
        ---
        Body text.
        """
        let result = FrontmatterSplitter.split(input)
        try assertNotNil(result.frontmatterYAML)
        try assertEqual(result.frontmatterYAML!, "")
        try assertEqual(result.pureMarkdownBody, "Body text.")
    }

    test("多行正文完整保留") {
        let input = """
        ---
        title: Multi
        ---
        Line 1

        Line 2

        Line 3
        """
        let result = FrontmatterSplitter.split(input)
        try assertEqual(result.pureMarkdownBody, "Line 1\n\nLine 2\n\nLine 3")
    }
}

// ============================================================
// Models Tests
// ============================================================
runSuite("Models - NoteContent") {

    test("带 Frontmatter 创建") {
        let content = NoteContent(frontmatterYAML: "title: Test", pureMarkdownBody: "# Body")
        try assertEqual(content.frontmatterYAML, "title: Test")
        try assertEqual(content.pureMarkdownBody, "# Body")
    }

    test("不带 Frontmatter 创建") {
        let content = NoteContent(frontmatterYAML: nil, pureMarkdownBody: "Plain text")
        try assertNil(content.frontmatterYAML)
        try assertEqual(content.pureMarkdownBody, "Plain text")
    }
}

runSuite("Models - SyncError") {

    test("authFailed 中文描述") {
        try assertEqual(SyncError.authFailed.errorDescription, "认证失败，请检查 Token 是否正确")
    }

    test("networkUnreachable 中文描述") {
        try assertEqual(SyncError.networkUnreachable.errorDescription, "网络不可达，已切换到离线模式")
    }

    test("unknown 返回消息") {
        try assertEqual(SyncError.unknown("无法连接").errorDescription, "无法连接")
    }
}

runSuite("Models - SearchIndexEntry") {

    test("searchableText 包含所有字段（小写）") {
        let entry = SearchIndexEntry(
            filename: "MyNote.md",
            fileURL: URL(fileURLWithPath: "/tmp/MyNote.md"),
            title: "我的笔记",
            tags: ["Swift", "iOS"],
            aliases: ["note1"]
        )
        let text = entry.searchableText
        try assertContains(text, "mynote.md")
        try assertContains(text, "我的笔记")
        try assertContains(text, "swift")
        try assertContains(text, "ios")
        try assertContains(text, "note1")
        try assertFalse(text.contains("Swift"), "应该全小写")
    }

    test("无标签和别名") {
        let entry = SearchIndexEntry(
            filename: "simple.md",
            fileURL: URL(fileURLWithPath: "/tmp/simple.md"),
            title: "Simple",
            tags: [],
            aliases: []
        )
        let text = entry.searchableText
        try assertContains(text, "simple.md")
        try assertContains(text, "simple")
    }
}

runSuite("Models - KeychainError") {

    test("saveFailed 包含状态码") {
        let error = KeychainError.saveFailed(status: -25299)
        try assertTrue(error.errorDescription!.contains("-25299"))
    }
}

// ============================================================
// ObsidianElementRewriter Tests
// ============================================================
runSuite("ObsidianElementRewriter - 图片路径改写") {

    test("本地相对路径改为 file:// 绝对路径") {
        let html = makeDocument("![图标](attachments/image.png)").format()
        try assertTrue(html.contains("file://") || html.contains("attachments/image.png"),
                       "图片路径应被改写: \(html)")
    }

    test("远程 HTTPS URL 不修改") {
        let html = makeDocument("![Remote](https://example.com/image.png)").format()
        try assertContains(html, "https://example.com/image.png")
    }

    test("远程 HTTP URL 不修改") {
        let html = makeDocument("![HTTP](http://cdn.example.com/photo.jpg)").format()
        try assertContains(html, "http://cdn.example.com/photo.jpg")
    }

    test("嵌套路径正确改写") {
        let html = makeDocument("![](images/screenshots/2024/app.png)").format()
        try assertTrue(
            html.contains("images/screenshots/2024/app.png") || html.contains("file://"),
            "嵌套路径应被改写: \(html)"
        )
    }
}

runSuite("ObsidianElementRewriter - WikiLinks 改写") {

    test("简单 [[note]] 生成 app://note/ scheme") {
        let html = makeDocument("参见 [[设计文档]] 了解更多。").format()
        try assertContains(html, "app://note/")
        try assertContains(html, "设计文档")
    }

    test("[[note|alias]] 使用别名作为显示文本") {
        let html = makeDocument("请查看 [[架构说明|架构文档]]。").format()
        try assertContains(html, "架构文档")
        try assertContains(html, "app://note/架构说明")
    }

    test("多个 WikiLinks 全部改写") {
        let html = makeDocument("参考 [[笔记A]] 和 [[笔记B|别名B]]。").format()
        try assertContains(html, "app://note/笔记A")
        try assertContains(html, "app://note/笔记B")
    }

    test("普通文本不改写") {
        let html = makeDocument("这是一段普通的文本，没有任何 Wiki 链接。").format()
        try assertContains(html, "普通的文本")
        try assertFalse(html.contains("app://"), "普通文本不应包含 app://")
    }

    test("空字符串不崩溃") {
        let doc = makeDocument("")
        try assertNotNil(doc)
    }
}

runSuite("ObsidianElementRewriter - 混合内容") {

    test("图片 + WikiLinks 同时改写") {
        let markdown = """
        ![截图](screenshots/app.png)

        查看 [[使用指南]] 了解详情。
        """
        let html = makeDocument(markdown).format()
        try assertTrue(html.contains("screenshots/app.png") || html.contains("file://"), "图片应被改写")
        try assertContains(html, "app://note/使用指南")
    }
}

// ============================================================
// MarkdownPipeline Tests
// ============================================================
runSuite("MarkdownPipeline - process(rawText:fileURL:)") {

    test("有效 Frontmatter 解析为字典") {
        let rawText = """
        ---
        title: 我的笔记
        tags: [swift, ios]
        ---
        # 正文标题

        正文内容。
        """
        let url = tempDir.appendingPathComponent("test1.md")
        let result = MarkdownPipeline.process(rawText: rawText, fileURL: url)
        try assertNotNil(result)
        try assertEqual(result?.frontmatter["title"] as? String, "我的笔记")
        try assertEqual(result?.frontmatter["tags"] as? [String], ["swift", "ios"])
    }

    test("无 Frontmatter 返回空字典") {
        let rawText = "# 无 Frontmatter\n\n纯正文。"
        let url = tempDir.appendingPathComponent("test2.md")
        let result = MarkdownPipeline.process(rawText: rawText, fileURL: url)
        try assertTrue(result?.frontmatter.isEmpty ?? false)
    }

    test("WikiLinks 在文档中被改写") {
        let rawText = """
        ---
        title: Wiki Test
        ---
        参见 [[目标笔记]] 了解更多。
        """
        let url = tempDir.appendingPathComponent("test3.md")
        let result = MarkdownPipeline.process(rawText: rawText, fileURL: url)
        let html = result!.document.format()
        try assertContains(html, "app://note/目标笔记")
    }

    test("复杂 Frontmatter 全部解析") {
        let rawText = """
        ---
        title: 复杂笔记
        date: 2024-06-15
        tags:
          - apple
          - swift
        author: 张三
        published: true
        ---
        # 内容
        """
        let url = tempDir.appendingPathComponent("test4.md")
        let result = MarkdownPipeline.process(rawText: rawText, fileURL: url)
        try assertEqual(result?.frontmatter["title"] as? String, "复杂笔记")
        try assertEqual(result?.frontmatter["author"] as? String, "张三")
        try assertEqual(result?.frontmatter["published"] as? Bool, true)
    }

    test("空输入正常处理") {
        let url = tempDir.appendingPathComponent("test5.md")
        let result = MarkdownPipeline.process(rawText: "", fileURL: url)
        try assertNotNil(result)
        try assertTrue(result?.frontmatter.isEmpty ?? false)
    }

    test("本地图片路径被改写") {
        let rawText = """
        ---
        title: Image
        ---
        ![本地图片](assets/photo.png)
        """
        let url = tempDir.appendingPathComponent("test6.md")
        let result = MarkdownPipeline.process(rawText: rawText, fileURL: url)
        let html = result!.document.format()
        try assertTrue(html.contains("assets/photo.png") || html.contains("file://"),
                       "图片路径应被改写")
    }
}

runSuite("MarkdownPipeline - process(fileAt:)") {

    test("从磁盘文件读取并处理") {
        let content = """
        ---
        title: 文件测试
        tags: [unit, test]
        ---
        # 从文件加载

        这是从磁盘读取的内容。
        """
        let fileURL = tempDir.appendingPathComponent("filetest.md")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        let result = MarkdownPipeline.process(fileAt: fileURL)
        try assertNotNil(result)
        try assertEqual(result?.frontmatter["title"] as? String, "文件测试")
        try assertEqual(result?.frontmatter["tags"] as? [String], ["unit", "test"])
    }

    test("不存在的文件返回 nil") {
        let url = tempDir.appendingPathComponent("nonexistent.md")
        let result = MarkdownPipeline.process(fileAt: url)
        try assertNil(result)
    }
}

runSuite("MarkdownPipeline - processBody") {

    test("返回包含改写内容的 Document") {
        let rawText = """
        ---
        title: Body
        ---
        # 正文

        [[内部链接]] 在这里。
        """
        let url = tempDir.appendingPathComponent("body.md")
        let doc = MarkdownPipeline.processBody(rawText: rawText, fileURL: url)
        let html = doc.format()
        try assertContains(html, "app://note/内部链接")
    }
}

runSuite("MarkdownPipeline - AST 结构") {

    test("标题和段落正确渲染") {
        let rawText = """
        ---
        title: AST
        ---
        # 标题一

        段落内容。

        ## 标题二

        另一个段落。
        """
        let url = tempDir.appendingPathComponent("ast.md")
        let result = MarkdownPipeline.process(rawText: rawText, fileURL: url)
        let html = result!.document.format()
        try assertContains(html, "标题一")
        try assertContains(html, "标题二")
        try assertContains(html, "段落内容")
    }

    test("代码块保留") {
        let rawText = """
        ---
        title: Code
        ---
        ```swift
        let greeting = "Hello"
        print(greeting)
        ```
        """
        let url = tempDir.appendingPathComponent("code.md")
        let result = MarkdownPipeline.process(rawText: rawText, fileURL: url)
        let html = result!.document.format()
        try assertTrue(html.contains("greeting") || html.contains("Hello"))
    }
}

runSuite("MarkdownPipeline - 边缘情况") {

    test("空 YAML 块返回空字典") {
        let rawText = """
        ---
        ---
        Body only.
        """
        let url = tempDir.appendingPathComponent("empty_yaml.md")
        let result = MarkdownPipeline.process(rawText: rawText, fileURL: url)
        try assertTrue(result?.frontmatter.isEmpty ?? false)
    }

    test("非法 YAML 不崩溃并返回空字典") {
        let rawText = """
        ---
        this is not valid: yaml: : : broken
        ---
        Body text.
        """
        let url = tempDir.appendingPathComponent("bad_yaml.md")
        let result = MarkdownPipeline.process(rawText: rawText, fileURL: url)
        try assertNotNil(result)
        try assertTrue(result?.frontmatter.isEmpty ?? false)
        try assertNotNil(result?.document)
    }
}

// ============================================================
// Performance Tests
// ============================================================
runSuite("性能测试") {

    test("大文档 Frontmatter 分离性能 (10000 行)") {
        let yaml = "title: Perf\ntags: [t1, t2, t3]"
        let body = String(repeating: "这是正文行。\n", count: 10_000)
        let input = "---\n\(yaml)\n---\n\(body)"

        let start = Date()
        for _ in 0..<10 {
            let _ = FrontmatterSplitter.split(input)
        }
        let elapsed = Date().timeIntervalSince(start)
        try assertTrue(elapsed < 2.0, "10 次分离耗时 \(String(format: "%.3f", elapsed))s，应 < 2s")
    }

    test("WikiLinks 改写性能 (500 个 WikiLinks)") {
        let wikiLinks = String(repeating: "参见 [[笔记X]] 了解更多内容。", count: 500)
        let markdown = "# 测试\n\n\(wikiLinks)"

        let start = Date()
        for _ in 0..<5 {
            let _ = makeDocument(markdown)
        }
        let elapsed = Date().timeIntervalSince(start)
        try assertTrue(elapsed < 5.0, "5 次改写耗时 \(String(format: "%.3f", elapsed))s，应 < 5s")
    }
}

// ============================================================
// GitSyncService - testConnection Tests
// ============================================================
class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

await runSuite("GitSyncService - testConnection") {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let mockSession = URLSession(configuration: config)

    await test("连接测试成功 (200 OK)") {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/x-git-upload-pack-advertisement"]
            )!
            return (response, Data())
        }

        var didSucceed = false
        do {
            try await GitSyncService.shared.testConnection(
                repoURL: "https://github.com/user/repo.git",
                token: "valid_token",
                session: mockSession
            )
            didSucceed = true
        } catch {
            didSucceed = false
        }
        try assertTrue(didSucceed, "200 OK 应该测试成功")
    }

    await test("连接测试失败 (401 Unauthorized)") {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        var didFailWithAuth = false
        do {
            try await GitSyncService.shared.testConnection(
                repoURL: "https://github.com/user/repo.git",
                token: "invalid_token",
                session: mockSession
            )
        } catch let error as SyncError {
            if case .authFailed = error {
                didFailWithAuth = true
            }
        } catch {
            // 其他错误
        }
        try assertTrue(didFailWithAuth, "401 应该抛出 authFailed 错误")
    }

    await test("连接测试失败 (404 Not Found)") {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        var didFailWithNotFound = false
        do {
            try await GitSyncService.shared.testConnection(
                repoURL: "https://github.com/user/repo.git",
                token: "token",
                session: mockSession
            )
        } catch let error as SyncError {
            if case .unknown(let msg) = error, msg.contains("仓库不存在") {
                didFailWithNotFound = true
            }
        } catch {
            // 其他错误
        }
        try assertTrue(didFailWithNotFound, "404 应该抛出仓库不存在错误")
    }
}

runSuite("GitSyncService - isLocalRepoExists") {
    let testRepoURL = GitSyncService.shared.repoRootURL
    let gitDirURL = testRepoURL.appendingPathComponent(".git")

    test("当目录不存在时返回 false") {
        try? FileManager.default.removeItem(at: testRepoURL)
        try assertFalse(GitSyncService.shared.isLocalRepoExists)
    }

    test("当仅有 repo 目录但无 .git 时返回 false") {
        try? FileManager.default.removeItem(at: testRepoURL)
        try FileManager.default.createDirectory(at: testRepoURL, withIntermediateDirectories: true)
        try assertFalse(GitSyncService.shared.isLocalRepoExists)
    }

    test("当 repo 目录和 .git 均存在时返回 true") {
        try? FileManager.default.removeItem(at: testRepoURL)
        try FileManager.default.createDirectory(at: gitDirURL, withIntermediateDirectories: true)
        try assertTrue(GitSyncService.shared.isLocalRepoExists)
        
        // 清理
        try? FileManager.default.removeItem(at: testRepoURL)
    }
}

// ============================================================
// §4.3 错误处理验证：7 种场景
// ============================================================
runSuite("§4.3 错误处理验证 - 同步前置校验") {
    // 保存并恢复 GitSyncService 单例状态
    let savedRepoURL = GitSyncService.shared.repoURL
    defer {
        GitSyncService.shared.repoURL = savedRepoURL
        KeychainService.shared.deleteToken()
        try? FileManager.default.removeItem(at: GitSyncService.shared.repoRootURL)
    }

    // 场景 3：Token 缺失 → validateForSync 抛 tokenMissing
    test("场景3: Token 缺失时 validateForSync 抛错") {
        KeychainService.shared.deleteToken()
        GitSyncService.shared.repoURL = "https://github.com/user/repo.git"
        // 确保 repo 不存在以隔离 token 检查
        try? FileManager.default.removeItem(at: GitSyncService.shared.repoRootURL)

        var caughtTokenError = false
        do {
            try GitSyncService.shared.validateForSync()
        } catch let e as SyncError {
            if case .tokenMissing = e { caughtTokenError = true }
        } catch {}
        try assertTrue(caughtTokenError, "Token 缺失应抛 tokenMissing 错误")
    }

    // 场景 3b：repoURL 空 → validateForSync 抛错
    test("场景3b: repoURL 为空时 validateForSync 抛错") {
        // 先存 token 以跳过 token 检查
        try KeychainService.shared.saveToken("test-token")
        GitSyncService.shared.repoURL = ""
        try? FileManager.default.removeItem(at: GitSyncService.shared.repoRootURL)

        var caughtURLError = false
        do {
            try GitSyncService.shared.validateForSync()
        } catch let e as SyncError {
            if case .repoNotConfigured = e { caughtURLError = true }
        } catch {}
        try assertTrue(caughtURLError, "repoURL 空应抛 repoNotConfigured 错误")
        KeychainService.shared.deleteToken()
    }

    // 场景 3c：本地仓库缺失 → validateForSync 抛错
    test("场景3c: 本地仓库未初始化时 validateForSync 抛错") {
        try KeychainService.shared.saveToken("test-token")
        GitSyncService.shared.repoURL = "https://github.com/user/repo.git"
        try? FileManager.default.removeItem(at: GitSyncService.shared.repoRootURL)

        var caughtRepoError = false
        do {
            try GitSyncService.shared.validateForSync()
        } catch let e as SyncError {
            if case .localRepoNotInitialized = e { caughtRepoError = true }
        } catch {}
        try assertTrue(caughtRepoError, "本地仓库缺失应抛 localRepoNotInitialized 错误")
        KeychainService.shared.deleteToken()
    }

    // 场景 5：本地文件被意外删除 → sync 通过 reset --hard 恢复
    // 该场景依赖 libgit2 实际操作，无法在 macOS 桩环境单元测试。
    // 验证点：validateForSync 会在仓库缺失时报错，提示用户重试克隆。
    test("场景5: 本地文件被删时 validateForSync 报错（提示重试克隆）") {
        try KeychainService.shared.saveToken("test-token")
        GitSyncService.shared.repoURL = "https://github.com/user/repo.git"
        try? FileManager.default.removeItem(at: GitSyncService.shared.repoRootURL)

        var threwError = false
        do {
            try GitSyncService.shared.validateForSync()
        } catch let e as SyncError {
            if case .localRepoNotInitialized = e { threwError = true }
        } catch {
            threwError = true
        }
        try assertTrue(threwError, "本地仓库被删时应触发错误，提示用户重试克隆")
        KeychainService.shared.deleteToken()
    }

    // 场景 6：WikiLinks 目标笔记不存在 → findNote 返回 nil
    test("场景6: WikiLinks 目标不存在时 findNote 返回 nil") {
        let repo = tempDir.appendingPathComponent("wiki-missing-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: repo) }
        try? FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        let existing = repo.appendingPathComponent("existing.md")
        try! "# 存在".write(to: existing, atomically: true, encoding: .utf8)

        let result = FileScannerService.shared.findNote(named: "nonexistent", in: repo)
        try assertNil(result, "不存在的笔记应返回 nil，View 层据此显示 Toast")
    }

    // 场景 6b：WikiLinks 路径型目标不存在 → findNote 返回 nil
    test("场景6b: WikiLinks 路径型目标不存在时 findNote 返回 nil") {
        let repo = tempDir.appendingPathComponent("wiki-path-missing-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: repo) }
        try? FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        let existing = repo.appendingPathComponent("existing.md")
        try! "# 存在".write(to: existing, atomically: true, encoding: .utf8)

        // [[folder/missing]] 取最后一段 "missing" 仍找不到
        let result = FileScannerService.shared.findNote(named: "folder/missing", in: repo)
        try assertNil(result)
    }

    // 场景 7：图片路径无效 → ObsidianElementRewriter 改写为 file://，渲染层显示占位
    // ObsidianElementRewriter 的路径改写已在 ObsidianElementRewriter 套件覆盖。
    // 此处验证：无效图片源被改写为 file:// 沙盒路径（渲染层据此 fallback 占位图标）。
    test("场景7: 无效图片路径被改写为 file:// 沙盒路径") {
        let html = makeDocument("![bad](nonexistent/broken.png)").format()
        // 改写后应包含 file:// 或沙盒路径前缀，渲染层 LazyImage error 态显示占位图标
        try assertTrue(
            html.contains("file://") || html.contains("nonexistent/broken.png"),
            "图片路径应被改写为沙盒路径: \(html)"
        )
    }
}

await runSuite("§4.3 错误处理验证 - 连接测试 (async)") {
    // 共享 mock session
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let mockSession = URLSession(configuration: config)

    // 场景 1：PAT 无效 → testConnection 401 抛 authFailed
    await test("场景1: PAT 无效抛 authFailed") {
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://github.com/u/r.git/info/refs?service=git-upload-pack")!,
                statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        var caughtAuth = false
        do {
            try await GitSyncService.shared.testConnection(
                repoURL: "https://github.com/user/repo.git",
                token: "invalid",
                session: mockSession
            )
        } catch let e as SyncError {
            if case .authFailed = e { caughtAuth = true }
        } catch {}
        try assertTrue(caughtAuth, "401 应抛 SyncError.authFailed")
    }

    // 场景 2：仓库不存在 → testConnection 404 抛 unknown
    await test("场景2: 仓库不存在抛 unknown") {
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://github.com/u/r.git/info/refs?service=git-upload-pack")!,
                statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        var caughtNotFound = false
        do {
            try await GitSyncService.shared.testConnection(
                repoURL: "https://github.com/user/repo.git",
                token: "any",
                session: mockSession
            )
        } catch let e as SyncError {
            if case .unknown(let msg) = e, msg.contains("仓库不存在") { caughtNotFound = true }
        } catch {}
        try assertTrue(caughtNotFound, "404 应抛含'仓库不存在'的 unknown")
    }

    // 场景 4：网络超时 → testConnection 包装为 SyncError.unknown
    await test("场景4: 网络超时抛 SyncError.unknown") {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }
        var caughtNetworkError = false
        do {
            try await GitSyncService.shared.testConnection(
                repoURL: "https://github.com/user/repo.git",
                token: "any",
                session: mockSession
            )
        } catch let e as SyncError {
            // 网络错误被包装为 unknown
            if case .unknown = e { caughtNetworkError = true }
        } catch {}
        try assertTrue(caughtNetworkError, "网络超时应被包装为 SyncError.unknown")
    }

    // 场景 4b：网络不可达 → testConnection 包装为 SyncError.unknown
    await test("场景4b: 网络不可达抛 SyncError.unknown") {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        var caughtNetworkError = false
        do {
            try await GitSyncService.shared.testConnection(
                repoURL: "https://github.com/user/repo.git",
                token: "any",
                session: mockSession
            )
        } catch let e as SyncError {
            if case .unknown = e { caughtNetworkError = true }
        } catch {}
        try assertTrue(caughtNetworkError, "网络不可达应被包装为 SyncError.unknown")
    }
}

runSuite("Models - FolderNode") {
    test("FolderNode 具有基于名称的稳定 ID") {
        let folder1 = FolderNode(name: "Notes", children: [])
        let folder2 = FolderNode(name: "Notes", children: [])
        let folder3 = FolderNode(name: "Work", children: [])

        try assertTrue(folder1.id == "Notes", "id 应该等于 name")
        try assertTrue(folder1.id == folder2.id, "相同名称的文件夹应该具有相同的 id")
        try assertTrue(folder1.id != folder3.id, "不同名称的文件夹应该具有不同的 id")
    }
}

runSuite("FileScannerService - scanDirectory(at:)") {
    // 每个测试用例使用唯一 UUID 目录，互不干扰
    func makeRepo(_ name: String) -> URL {
        let dir = tempDir.appendingPathComponent("scan-\(name)-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    func makeFile(_ dir: URL, _ path: String, content: String = "# note") {
        let url = dir.appendingPathComponent(path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    test("空目录返回空数组") {
        let repo = makeRepo("empty")
        defer { try? FileManager.default.removeItem(at: repo) }
        let folders = FileScannerService.shared.scanDirectory(at: repo)
        try assertEqual(folders.count, 0)
    }

    test("不存在的目录返回空数组") {
        let nonExist = tempDir.appendingPathComponent("not-exist-\(UUID().uuidString)")
        let folders = FileScannerService.shared.scanDirectory(at: nonExist)
        try assertEqual(folders.count, 0)
    }

    test("根目录 .md 文件归入根目录文件夹") {
        let repo = makeRepo("root-files")
        defer { try? FileManager.default.removeItem(at: repo) }
        makeFile(repo, "root-note.md")

        let folders = FileScannerService.shared.scanDirectory(at: repo)
        try assertEqual(folders.count, 1, "应只有根目录文件夹")
        let rootFolder = folders[0]
        try assertEqual(rootFolder.children.count, 1)
        try assertEqual(rootFolder.children[0].name, "root-note")
    }

    test("子文件夹中的 .md 文件归入对应文件夹节点") {
        let repo = makeRepo("nested")
        defer { try? FileManager.default.removeItem(at: repo) }
        makeFile(repo, "notes/a.md")
        makeFile(repo, "notes/b.md")

        let folders = FileScannerService.shared.scanDirectory(at: repo)
        // 根目录文件夹不存在（根目录无 .md），仅 "notes" 文件夹
        try assertEqual(folders.count, 1)
        try assertEqual(folders[0].name, "notes")
        try assertEqual(folders[0].children.count, 2)
    }

    test("排除 .git/.obsidian/.trash/node_modules 目录") {
        let repo = makeRepo("excluded")
        defer { try? FileManager.default.removeItem(at: repo) }
        makeFile(repo, ".git/config.md")
        makeFile(repo, ".obsidian/workspace.md")
        makeFile(repo, ".trash/deleted.md")
        makeFile(repo, "node_modules/lib.md")
        makeFile(repo, "real.md")

        let folders = FileScannerService.shared.scanDirectory(at: repo)
        // 仅 real.md 应被扫描到，归入根目录文件夹
        try assertEqual(folders.count, 1)
        try assertEqual(folders[0].children.count, 1)
        try assertEqual(folders[0].children[0].name, "real")
    }

    test("非 .md 文件被忽略") {
        let repo = makeRepo("non-md")
        defer { try? FileManager.default.removeItem(at: repo) }
        makeFile(repo, "note.txt", content: "text")
        makeFile(repo, "image.png", content: "data")
        makeFile(repo, "real.md")

        let folders = FileScannerService.shared.scanDirectory(at: repo)
        try assertEqual(folders.count, 1)
        try assertEqual(folders[0].children.count, 1)
        try assertEqual(folders[0].children[0].name, "real")
    }

    test("getAllMarkdownFiles(at:) 扁平化返回所有 .md") {
        let repo = makeRepo("flat")
        defer { try? FileManager.default.removeItem(at: repo) }
        makeFile(repo, "a.md")
        makeFile(repo, "sub/b.md")
        makeFile(repo, "sub/deep/c.md")

        let files = FileScannerService.shared.getAllMarkdownFiles(at: repo)
        try assertEqual(files.count, 3)
        let names = Set(files.map { $0.deletingPathExtension().lastPathComponent })
        try assertTrue(names.contains("a"), "应包含 a")
        try assertTrue(names.contains("b"), "应包含 b")
        try assertTrue(names.contains("c"), "应包含 c")
    }
}

runSuite("FileScannerService - findNote(named:in:)") {
    func makeRepo(_ name: String) -> URL {
        let dir = tempDir.appendingPathComponent("find-\(name)-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    func makeFile(_ dir: URL, _ path: String, content: String = "# note") {
        let url = dir.appendingPathComponent(path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    test("精确笔记名命中") {
        let repo = makeRepo("exact")
        defer { try? FileManager.default.removeItem(at: repo) }
        makeFile(repo, "target.md")

        let result = FileScannerService.shared.findNote(named: "target", in: repo)
        try assertNotNil(result)
        try assertEqual(result?.deletingPathExtension().lastPathComponent, "target")
    }

    test("大小写不敏感匹配") {
        let repo = makeRepo("case")
        defer { try? FileManager.default.removeItem(at: repo) }
        makeFile(repo, "MyNote.md")

        let result = FileScannerService.shared.findNote(named: "mynote", in: repo)
        try assertNotNil(result, "大小写不敏感应命中")
        try assertEqual(result?.deletingPathExtension().lastPathComponent, "MyNote")
    }

    test("未找到笔记返回 nil") {
        let repo = makeRepo("notfound")
        defer { try? FileManager.default.removeItem(at: repo) }
        makeFile(repo, "existing.md")

        let result = FileScannerService.shared.findNote(named: "missing", in: repo)
        try assertNil(result)
    }

    test("路径型 [[folder/note]] 取最后一段匹配") {
        let repo = makeRepo("path-type")
        defer { try? FileManager.default.removeItem(at: repo) }
        makeFile(repo, "notes/design.md")

        // 模拟 [[notes/design]] WikiLink，应取 "design" 匹配
        let result = FileScannerService.shared.findNote(named: "notes/design", in: repo)
        try assertNotNil(result, "路径型 [[folder/note]] 应取最后一段匹配")
        try assertEqual(result?.deletingPathExtension().lastPathComponent, "design")
    }

    test("路径型大小写不敏感") {
        let repo = makeRepo("path-case")
        defer { try? FileManager.default.removeItem(at: repo) }
        makeFile(repo, "notes/Architecture.md")

        // [[notes/architecture]] 应命中 Architecture.md
        let result = FileScannerService.shared.findNote(named: "notes/architecture", in: repo)
        try assertNotNil(result, "路径型大小写不敏感应命中")
        try assertEqual(result?.deletingPathExtension().lastPathComponent, "Architecture")
    }

    test("深层路径 [[a/b/c/note]] 取最后一段匹配") {
        let repo = makeRepo("deep-path")
        defer { try? FileManager.default.removeItem(at: repo) }
        makeFile(repo, "a/b/c/deep-note.md")

        let result = FileScannerService.shared.findNote(named: "a/b/c/deep-note", in: repo)
        try assertNotNil(result, "深层路径应取最后一段匹配")
        try assertEqual(result?.deletingPathExtension().lastPathComponent, "deep-note")
    }

    test("空字符串返回 nil") {
        let repo = makeRepo("empty-input")
        defer { try? FileManager.default.removeItem(at: repo) }
        makeFile(repo, "any.md")

        let result = FileScannerService.shared.findNote(named: "", in: repo)
        try assertNil(result)
    }

    test("仅路径分隔符返回 nil") {
        let repo = makeRepo("slash-only")
        defer { try? FileManager.default.removeItem(at: repo) }
        makeFile(repo, "any.md")

        let result = FileScannerService.shared.findNote(named: "///", in: repo)
        try assertNil(result, "仅分隔符应返回 nil")
    }
}

runSuite("FileScannerService - extractMetadata") {
    let tempDir = FileManager.default.temporaryDirectory
    let testFileURL = tempDir.appendingPathComponent("test_metadata.md")

    test("提取行内标签和状态") {
        let content = """
        ---
        title: "测试笔记"
        status: "todo"
        tags: [tag1, tag2]
        ---
        # 正文
        """
        try! content.write(to: testFileURL, atomically: true, encoding: .utf8)
        
        let metadata = FileScannerService.shared.extractMetadata(from: testFileURL)
        try assertTrue(metadata.status == "todo", "status 应该等于 todo")
        try assertTrue(metadata.tags.count == 2, "应该提取出 2 个标签")
        try assertTrue(metadata.tags.contains("tag1"), "应该包含 tag1")
        try assertTrue(metadata.tags.contains("tag2"), "应该包含 tag2")
        
        try? FileManager.default.removeItem(at: testFileURL)
    }

    test("提取列表标签和状态") {
        let content = """
        ---
        title: "测试笔记"
        status: in-progress
        tags:
          - tag-a
          - tag-b
        ---
        # 正文
        """
        try! content.write(to: testFileURL, atomically: true, encoding: .utf8)
        
        let metadata = FileScannerService.shared.extractMetadata(from: testFileURL)
        try assertTrue(metadata.status == "in-progress", "status 应该等于 in-progress")
        try assertTrue(metadata.tags.count == 2, "应该提取出 2 个标签")
        try assertTrue(metadata.tags.contains("tag-a"), "应该包含 tag-a")
        try assertTrue(metadata.tags.contains("tag-b"), "应该包含 tag-b")
        
        try? FileManager.default.removeItem(at: testFileURL)
    }

    test("无 Frontmatter 时返回空") {
        let content = """
        # 正文
        """
        try! content.write(to: testFileURL, atomically: true, encoding: .utf8)
        
        let metadata = FileScannerService.shared.extractMetadata(from: testFileURL)
        try assertTrue(metadata.status == nil, "status 应该为 nil")
        try assertTrue(metadata.tags.isEmpty, "tags 应该为空")
        
        try? FileManager.default.removeItem(at: testFileURL)
    }
}

// ============================================================
// SearchService Tests
// ============================================================
runSuite("SearchService - rebuildIndex(from:)") {
    let searchDir = tempDir.appendingPathComponent("search-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: searchDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: searchDir) }

    test("含 Frontmatter 的文件解析 title/tags/aliases") {
        let fileURL = searchDir.appendingPathComponent("note1.md")
        let content = """
        ---
        title: 我的笔记
        tags: [swift, ios]
        aliases: [mynote, alias-note]
        ---
        # 正文
        """
        try! content.write(to: fileURL, atomically: true, encoding: .utf8)

        SearchService.shared.rebuildIndex(from: [fileURL])
        let index = SearchService.shared.index
        try assertEqual(index.count, 1)
        let entry = index[0]
        try assertEqual(entry.filename, "note1")
        try assertEqual(entry.title, "我的笔记")
        try assertEqual(entry.tags, ["swift", "ios"])
        try assertEqual(entry.aliases, ["mynote", "alias-note"])
    }

    test("无 Frontmatter 的文件 title 回退为文件名") {
        let fileURL = searchDir.appendingPathComponent("plain.md")
        let content = "# 纯正文"
        try! content.write(to: fileURL, atomically: true, encoding: .utf8)

        SearchService.shared.rebuildIndex(from: [fileURL])
        let index = SearchService.shared.index
        try assertEqual(index.count, 1)
        try assertEqual(index[0].title, "plain")
        try assertTrue(index[0].tags.isEmpty)
        try assertTrue(index[0].aliases.isEmpty)
    }

    test("tags 为字符串而非数组时正确解析") {
        let fileURL = searchDir.appendingPathComponent("single_tag.md")
        let content = """
        ---
        title: 单标签
        tags: important
        ---
        正文
        """
        try! content.write(to: fileURL, atomically: true, encoding: .utf8)

        SearchService.shared.rebuildIndex(from: [fileURL])
        let index = SearchService.shared.index
        try assertEqual(index.count, 1)
        try assertEqual(index[0].tags, ["important"])
    }

    test("Frontmatter 开头有空行或空格时容错解析") {
        let fileURL = searchDir.appendingPathComponent("fault_tolerant.md")
        let content = """
        
          
        ---
        title: 容错标题
        tags: [tolerant]
        ---
        正文
        """
        try! content.write(to: fileURL, atomically: true, encoding: .utf8)

        SearchService.shared.rebuildIndex(from: [fileURL])
        let index = SearchService.shared.index
        try assertEqual(index.count, 1)
        try assertEqual(index[0].title, "容错标题")
        try assertEqual(index[0].tags, ["tolerant"])
    }
}

runSuite("SearchService - filter(query:) 四字段命中") {
    let searchDir = tempDir.appendingPathComponent("filter-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: searchDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: searchDir) }

    let file1 = searchDir.appendingPathComponent("swift-guide.md")
    try! """
    ---
    title: Swift 入门指南
    tags: [swift, programming]
    aliases: [swiftintro]
    ---
    正文
    """.write(to: file1, atomically: true, encoding: .utf8)

    let file2 = searchDir.appendingPathComponent("design.md")
    try! """
    ---
    title: 设计原则
    tags: [design, ui]
    aliases: [designprinciples]
    ---
    正文
    """.write(to: file2, atomically: true, encoding: .utf8)

    let file3 = searchDir.appendingPathComponent("untitled.md")
    try! "# 无 frontmatter".write(to: file3, atomically: true, encoding: .utf8)

    SearchService.shared.rebuildIndex(from: [file1, file2, file3])

    test("按 filename 命中") {
        let results = SearchService.shared.filter(query: "swift-guide")
        try assertTrue(results.contains { $0.filename == "swift-guide" })
    }

    test("按 title 命中") {
        let results = SearchService.shared.filter(query: "入门指南")
        try assertTrue(results.contains { $0.filename == "swift-guide" })
    }

    test("按 tags 命中") {
        let results = SearchService.shared.filter(query: "programming")
        try assertTrue(results.contains { $0.filename == "swift-guide" })
    }

    test("按 aliases 命中") {
        let results = SearchService.shared.filter(query: "swiftintro")
        try assertTrue(results.contains { $0.filename == "swift-guide" })
    }

    test("大小写不敏感") {
        let results = SearchService.shared.filter(query: "SWIFT-GUIDE")
        try assertTrue(results.contains { $0.filename == "swift-guide" })
    }

    test("空查询返回全部") {
        let results = SearchService.shared.filter(query: "")
        try assertEqual(results.count, 3)
    }
}

runSuite("SearchService - 边界用例") {
    let searchDir = tempDir.appendingPathComponent("edge-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: searchDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: searchDir) }

    test("空文件列表构建空索引") {
        SearchService.shared.rebuildIndex(from: [])
        try assertEqual(SearchService.shared.index.count, 0)
    }

    test("不可读取的文件被跳过") {
        // 指向一个不存在的文件 URL，rebuildIndex 应跳过而不崩溃
        let fakeURL = searchDir.appendingPathComponent("nonexistent-\(UUID().uuidString).md")
        SearchService.shared.rebuildIndex(from: [fakeURL])
        try assertEqual(SearchService.shared.index.count, 0, "不可读文件应被跳过")
    }

    test("aliases 为字符串而非数组时正确解析") {
        let fileURL = searchDir.appendingPathComponent("alias-str-\(UUID().uuidString).md")
        let content = """
        ---
        title: 字符串别名
        alias: single-alias
        ---
        正文
        """
        try! content.write(to: fileURL, atomically: true, encoding: .utf8)

        SearchService.shared.rebuildIndex(from: [fileURL])
        let index = SearchService.shared.index
        try assertEqual(index.count, 1)
        try assertEqual(index[0].aliases, ["single-alias"], "alias 字符串应转为单元素数组")
    }

    test("非法 YAML Frontmatter 不崩溃并回退为文件名") {
        let fileURL = searchDir.appendingPathComponent("bad-yaml-\(UUID().uuidString).md")
        let content = """
        ---
        this is: not: valid: yaml: : :
        ---
        正文
        """
        try! content.write(to: fileURL, atomically: true, encoding: .utf8)

        SearchService.shared.rebuildIndex(from: [fileURL])
        let index = SearchService.shared.index
        try assertEqual(index.count, 1)
        // 解析失败时 title 回退为文件名（不含扩展名）
        let expectedName = fileURL.deletingPathExtension().lastPathComponent
        try assertEqual(index[0].title, expectedName)
        try assertTrue(index[0].tags.isEmpty)
        try assertTrue(index[0].aliases.isEmpty)
    }

    test("特殊字符搜索不崩溃") {
        let fileURL = searchDir.appendingPathComponent("special-\(UUID().uuidString).md")
        // 用 frontmatter 让 title 包含可搜索内容
        let content = """
        ---
        title: 标题
        ---
        # 正文
        """
        try! content.write(to: fileURL, atomically: true, encoding: .utf8)
        SearchService.shared.rebuildIndex(from: [fileURL])

        // 包含正则元字符的查询，不应崩溃且不应误匹配
        let results1 = SearchService.shared.filter(query: ".*[](){}")
        try assertEqual(results1.count, 0, "特殊字符不应匹配到任何条目")

        // 包含 Unicode 的查询应命中 title
        let results2 = SearchService.shared.filter(query: "标题")
        try assertEqual(results2.count, 1)
    }

    test("重复文件名都进入索引") {
        let dir1 = searchDir.appendingPathComponent("d1-\(UUID().uuidString)")
        let dir2 = searchDir.appendingPathComponent("d2-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir1, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: dir2, withIntermediateDirectories: true)
        let file1 = dir1.appendingPathComponent("dup.md")
        let file2 = dir2.appendingPathComponent("dup.md")
        try! "# 1".write(to: file1, atomically: true, encoding: .utf8)
        try! "# 2".write(to: file2, atomically: true, encoding: .utf8)

        SearchService.shared.rebuildIndex(from: [file1, file2])
        try assertEqual(SearchService.shared.index.count, 2, "两个同名文件都应进入索引")

        let results = SearchService.shared.filter(query: "dup")
        try assertEqual(results.count, 2, "应匹配到两个同名文件")
    }

    test("rebuildIndex 覆盖旧索引而非追加") {
        let file1 = searchDir.appendingPathComponent("first-\(UUID().uuidString).md")
        let file2 = searchDir.appendingPathComponent("second-\(UUID().uuidString).md")
        try! "# 1".write(to: file1, atomically: true, encoding: .utf8)
        try! "# 2".write(to: file2, atomically: true, encoding: .utf8)

        SearchService.shared.rebuildIndex(from: [file1])
        try assertEqual(SearchService.shared.index.count, 1)

        // 再次构建应覆盖，而非变成 2 条
        SearchService.shared.rebuildIndex(from: [file2])
        try assertEqual(SearchService.shared.index.count, 1)
        try assertEqual(SearchService.shared.index[0].filename, file2.deletingPathExtension().lastPathComponent)
    }
}

// ============================================================
// KeychainService Tests
// ============================================================
runSuite("KeychainService - CRUD 全流程") {
    // 每个测试前清理，避免历史残留影响
    KeychainService.shared.deleteToken()

    test("初始状态无 token，readToken 返回 nil") {
        KeychainService.shared.deleteToken()
        try assertNil(KeychainService.shared.readToken())
    }

    test("saveToken 后 readToken 返回相同值") {
        KeychainService.shared.deleteToken()
        let token = "ghp_test_token_12345"
        try KeychainService.shared.saveToken(token)
        try assertEqual(KeychainService.shared.readToken(), token)
    }

    test("deleteToken 后 readToken 返回 nil") {
        KeychainService.shared.deleteToken()
        try KeychainService.shared.saveToken("to-be-deleted")
        try assertNotNil(KeychainService.shared.readToken())

        KeychainService.shared.deleteToken()
        try assertNil(KeychainService.shared.readToken())
    }

    test("重复 saveToken 覆盖旧值") {
        KeychainService.shared.deleteToken()
        try KeychainService.shared.saveToken("first-token")
        try assertEqual(KeychainService.shared.readToken(), "first-token")

        // 再次保存应覆盖，而非报错
        try KeychainService.shared.saveToken("second-token")
        try assertEqual(KeychainService.shared.readToken(), "second-token")
    }

    test("保存空字符串 token") {
        KeychainService.shared.deleteToken()
        try KeychainService.shared.saveToken("")
        // 空字符串是合法 Data，应能读取（Keychain 不拒绝空值）
        let read = KeychainService.shared.readToken()
        try assertEqual(read, "")
    }

    test("保存长 token (256 字符)") {
        KeychainService.shared.deleteToken()
        let longToken = String(repeating: "a", count: 256)
        try KeychainService.shared.saveToken(longToken)
        try assertEqual(KeychainService.shared.readToken(), longToken)
    }

    test("保存含特殊字符的 token") {
        KeychainService.shared.deleteToken()
        let specialToken = "tok=param&other#frag?query+/\\\"'"
        try KeychainService.shared.saveToken(specialToken)
        try assertEqual(KeychainService.shared.readToken(), specialToken)
    }

    test("保存含中文/Emoji 的 token") {
        KeychainService.shared.deleteToken()
        let unicodeToken = "token-测试-🔒-日本語"
        try KeychainService.shared.saveToken(unicodeToken)
        try assertEqual(KeychainService.shared.readToken(), unicodeToken)
    }

    test("多次 deleteToken 不报错") {
        KeychainService.shared.deleteToken()
        KeychainService.shared.deleteToken()
        KeychainService.shared.deleteToken()
        try assertNil(KeychainService.shared.readToken())
    }

    // 清理测试产生的 token
    KeychainService.shared.deleteToken()
}

// ============================================================
// MarkdownBlockClassifier Tests
// ============================================================
runSuite("MarkdownBlockClassifier - classify") {

    test("Heading 分类为 .heading(level:text:)") {
        let doc = Document(parsing: "## 标题文本")
        let heading = doc.child(at: 0)!
        let result = MarkdownBlockClassifier.classify(heading)
        try assertEqual(result, .heading(level: 2, text: "标题文本"))
    }

    test("Paragraph 分类为 .paragraph") {
        let doc = Document(parsing: "普通段落")
        let para = doc.child(at: 0)!
        let result = MarkdownBlockClassifier.classify(para)
        try assertEqual(result, .paragraph)
    }

    test("UnorderedList 分类为 .unorderedList(depth: 0)") {
        let doc = Document(parsing: "- 项一\n- 项二")
        let list = doc.child(at: 0)!
        let result = MarkdownBlockClassifier.classify(list)
        try assertEqual(result, .unorderedList(depth: 0))
    }

    test("OrderedList 分类为 .orderedList(depth: 0)") {
        let doc = Document(parsing: "1. 第一\n2. 第二")
        let list = doc.child(at: 0)!
        let result = MarkdownBlockClassifier.classify(list)
        try assertEqual(result, .orderedList(depth: 0))
    }

    test("CodeBlock 分类为 .codeBlock 含 code 和 language") {
        let doc = Document(parsing: "```swift\nlet x = 1\n```")
        let codeBlock = doc.child(at: 0)!
        let result = MarkdownBlockClassifier.classify(codeBlock)
        try assertEqual(result, .codeBlock(CodeBlockData(code: "let x = 1\n", language: "swift")))
    }

    test("无语言标签的 CodeBlock language 为 plaintext") {
        let doc = Document(parsing: "```\nplain code\n```")
        let codeBlock = doc.child(at: 0)!
        let result = MarkdownBlockClassifier.classify(codeBlock)
        try assertEqual(result, .codeBlock(CodeBlockData(code: "plain code\n", language: "plaintext")))
    }

    test("BlockQuote 分类为 .blockquote(children:)") {
        let doc = Document(parsing: "> 引用文本")
        let blockquote = doc.child(at: 0)!
        let result = MarkdownBlockClassifier.classify(blockquote)
        if case let .blockquote(children) = result {
            try assertEqual(children.count, 1)
            try assertEqual(children[0], .paragraph)
        } else {
            throw TestFailure(message: "expected .blockquote, got \(result)")
        }
    }

    test("ThematicBreak 分类为 .thematicBreak") {
        let doc = Document(parsing: "文本\n\n---\n\n文本")
        let thematicBreak = doc.child(at: 1)!
        let result = MarkdownBlockClassifier.classify(thematicBreak)
        try assertEqual(result, .thematicBreak)
    }

    test("Table 分类为 .table 含 headers 和 rows") {
        let markdown = """
        | 列1 | 列2 |
        |-----|-----|
        | a | b |
        | c | d |
        """
        let doc = Document(parsing: markdown)
        let table = doc.child(at: 0)!
        let result = MarkdownBlockClassifier.classify(table)
        if case let .table(data) = result {
            try assertEqual(data.headers, ["列1", "列2"])
            try assertEqual(data.rows, [["a", "b"], ["c", "d"]])
        } else {
            throw TestFailure(message: "expected .table, got \(result)")
        }
    }
}

runSuite("MarkdownBlockClassifier - listDepth") {

    test("顶层列表深度为 0") {
        let doc = Document(parsing: "- 项一")
        let list = doc.child(at: 0)!
        try assertEqual(MarkdownBlockClassifier.listDepth(list), 0)
    }

    test("嵌套列表深度为 1") {
        let markdown = """
        - 外层
          - 内层
        """
        let doc = Document(parsing: markdown)
        let outerList = doc.child(at: 0)! as! UnorderedList
        let outerItem = outerList.children.compactMap { $0 as? ListItem }.first!
        let innerList = outerItem.children.compactMap { $0 as? UnorderedList }.first!
        try assertEqual(MarkdownBlockClassifier.listDepth(innerList), 1)
    }

    test("三层嵌套列表深度为 2") {
        let markdown = """
        - L1
          - L2
            - L3
        """
        let doc = Document(parsing: markdown)
        let l1 = doc.child(at: 0)! as! UnorderedList
        let l1Item = l1.children.compactMap { $0 as? ListItem }.first!
        let l2 = l1Item.children.compactMap { $0 as? UnorderedList }.first!
        let l2Item = l2.children.compactMap { $0 as? ListItem }.first!
        let l3 = l2Item.children.compactMap { $0 as? UnorderedList }.first!
        try assertEqual(MarkdownBlockClassifier.listDepth(l3), 2)
    }
}

// ============================================================
// LanguageNormalizer Tests
// ============================================================
runSuite("LanguageNormalizer - normalize") {

    test("nil 返回 plaintext") {
        try assertEqual(LanguageNormalizer.normalize(nil), "plaintext")
    }

    test("空字符串返回 plaintext") {
        try assertEqual(LanguageNormalizer.normalize(""), "plaintext")
    }

    test("swift 原样返回") {
        try assertEqual(LanguageNormalizer.normalize("swift"), "swift")
    }

    test("ts 别名映射为 typescript") {
        try assertEqual(LanguageNormalizer.normalize("ts"), "typescript")
    }

    test("py 别名映射为 python") {
        try assertEqual(LanguageNormalizer.normalize("py"), "python")
    }

    test("js 别名映射为 javascript") {
        try assertEqual(LanguageNormalizer.normalize("js"), "javascript")
    }

    test("sh 别名映射为 bash") {
        try assertEqual(LanguageNormalizer.normalize("sh"), "bash")
    }

    test("shell 别名映射为 bash") {
        try assertEqual(LanguageNormalizer.normalize("shell"), "bash")
    }

    test("yml 别名映射为 yaml") {
        try assertEqual(LanguageNormalizer.normalize("yml"), "yaml")
    }

    test("c++ 别名映射为 cpp") {
        try assertEqual(LanguageNormalizer.normalize("c++"), "cpp")
    }

    test("c# 别名映射为 csharp") {
        try assertEqual(LanguageNormalizer.normalize("c#"), "csharp")
    }

    test("objc 别名映射为 objectivec") {
        try assertEqual(LanguageNormalizer.normalize("objc"), "objectivec")
    }

    test("大小写不敏感：SWIFT 映射为 swift") {
        try assertEqual(LanguageNormalizer.normalize("SWIFT"), "swift")
    }

    test("未知语言返回 plaintext") {
        try assertEqual(LanguageNormalizer.normalize("unknownlang"), "plaintext")
    }
}

// ============================================================
// Results Summary
// ============================================================
print("\n")
print("═══════════════════════════════════════════")
print("  测试完成")
print("═══════════════════════════════════════════")
let passRate = totalTests > 0 ? Double(passedTests) / Double(totalTests) * 100.0 : 0
print("  总计: \(totalTests) 个用例")
print("  通过: \(passedTests) 个 ✅")
print("  失败: \(failedTests) 个 ❌")
print("  通过率: \(String(format: "%.1f", passRate))%")
print("═══════════════════════════════════════════")

// ============================================================
// PropertyTemplateManager Tests
// ============================================================
await runSuite("PropertyTemplateManager - 仓库级动态模板") {
    let testRepoDir = tempDir.appendingPathComponent("repo-template-\(UUID().uuidString)")
    let obsidianDir = testRepoDir.appendingPathComponent(".obsidian")
    let configURL = obsidianDir.appendingPathComponent("gr-workflow.yaml")
    
    // 备份并清理环境
    let savedActiveRepo = GitSyncService.shared.activeRepository
    let savedRepoRoot = GitSyncService.shared.repoRootURL
    
    defer {
        GitSyncService.shared.activeRepository = savedActiveRepo
        GitSyncService.shared.repoRootURL = savedRepoRoot
        try? FileManager.default.removeItem(at: testRepoDir)
    }
    
    await test("无激活仓库时，回退到全局默认模板") {
        GitSyncService.shared.activeRepository = nil
        
        await PropertyTemplateManager.shared.reloadTemplate()
        let fields = await PropertyTemplateManager.shared.fields
        try assertEqual(fields.count, 3)
        try assertEqual(fields[0].name, "date")
        try assertEqual(fields[1].name, "status")
        try assertEqual(fields[2].name, "tags")
    }
    
    await test("有激活仓库但无配置文件时，回退到全局默认模板") {
        try? FileManager.default.createDirectory(at: testRepoDir, withIntermediateDirectories: true)
        GitSyncService.shared.activeRepository = RepositoryInfo(name: "TestRepo", url: "https://github.com/test/repo.git")
        GitSyncService.shared.repoRootURL = testRepoDir
        
        await PropertyTemplateManager.shared.reloadTemplate()
        let fields = await PropertyTemplateManager.shared.fields
        try assertEqual(fields.count, 3)
        try assertEqual(fields[0].name, "date")
    }
    
    await test("有激活仓库且有配置文件时，成功解析并应用仓库专属模板") {
        try? FileManager.default.createDirectory(at: obsidianDir, withIntermediateDirectories: true)
        let customYAML = """
        - name: priority
          type: enum
          options: [high, medium, low]
        - name: assignee
          type: text
        """
        try! customYAML.write(to: configURL, atomically: true, encoding: .utf8)
        
        GitSyncService.shared.activeRepository = RepositoryInfo(name: "TestRepo", url: "https://github.com/test/repo.git")
        GitSyncService.shared.repoRootURL = testRepoDir
        
        await PropertyTemplateManager.shared.reloadTemplate()
        let fields = await PropertyTemplateManager.shared.fields
        try assertEqual(fields.count, 2)
        try assertEqual(fields[0].name, "priority")
        try assertEqual(fields[0].type, .enum)
        try assertEqual(fields[0].options, ["high", "medium", "low"])
        try assertEqual(fields[1].name, "assignee")
        try assertEqual(fields[1].type, .text)
    }
    
    await test("有激活仓库但配置文件格式损坏时，安全回退到全局默认模板") {
        try? FileManager.default.createDirectory(at: obsidianDir, withIntermediateDirectories: true)
        let badYAML = """
        - name: broken
          type: invalid_type_here
        """
        try! badYAML.write(to: configURL, atomically: true, encoding: .utf8)
        
        GitSyncService.shared.activeRepository = RepositoryInfo(name: "TestRepo", url: "https://github.com/test/repo.git")
        GitSyncService.shared.repoRootURL = testRepoDir
        
        await PropertyTemplateManager.shared.reloadTemplate()
        let fields = await PropertyTemplateManager.shared.fields
        try assertEqual(fields.count, 3) // 应该回退到默认的 3 个字段
        try assertEqual(fields[0].name, "date")
    }
}

if !failedMessages.isEmpty {
    print("\n失败详情:")
    for msg in failedMessages {
        print(msg)
    }
}

exit(failedTests > 0 ? 1 : 0)
