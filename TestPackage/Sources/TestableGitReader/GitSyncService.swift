import Foundation

/// 桩实现：提供 FileScannerService 所需的 repoRootURL
/// 在没有 swift-libgit2 的环境中运行单元测试使用
final class GitSyncService {
    static let shared = GitSyncService()

    var repoURL: String = ""
    var branch: String = "main"

    var isConfigured: Bool {
        return !repoURL.isEmpty
    }

    var isLocalRepoExists: Bool {
        let gitDir = repoRootURL.appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitDir.path)
    }

    private init() {}

    var repoRootURL: URL {
        return URL(fileURLWithPath: "/tmp/gitreader-test-repo")
    }

    func sync() async throws {
        // 桩实现：无操作
    }

    /// 测试连接（使用 HTTP Session 级别的连接测试）
    func testConnection(repoURL: String, token: String, session: URLSession = .shared) async throws {
        guard var components = URLComponents(string: repoURL) else {
            throw SyncError.unknown("无效的仓库地址")
        }
        
        // 规范化路径，确保以 /info/refs 结尾
        if components.path.hasSuffix(".git") {
            components.path += "/info/refs"
        } else {
            if !components.path.hasSuffix("/") {
                components.path += "/"
            }
            components.path += "info/refs"
        }
        
        components.queryItems = [URLQueryItem(name: "service", value: "git-upload-pack")]
        
        guard let url = components.url else {
            throw SyncError.unknown("无法构建测试连接 URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0 // 10秒超时
        
        if !token.isEmpty {
            let credentialString = "token:\(token)"
            if let credentialData = credentialString.data(using: .utf8) {
                let base64Credentials = credentialData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }
        
        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SyncError.unknown("无效的服务器响应")
            }
            
            switch httpResponse.statusCode {
            case 200:
                return // 测试通过
            case 401, 403:
                throw SyncError.authFailed
            case 404:
                throw SyncError.unknown("仓库不存在，请检查地址是否正确")
            default:
                throw SyncError.unknown("连接失败，HTTP 状态码: \(httpResponse.statusCode)")
            }
        } catch let error as SyncError {
            throw error
        } catch {
            throw SyncError.unknown("连接测试失败: \(error.localizedDescription)")
        }
    }
}
