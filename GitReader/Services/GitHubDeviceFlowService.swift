import Foundation

struct GitHubDeviceCodeResponse: Codable {
    let device_code: String
    let user_code: String
    let verification_uri: String
    let expires_in: Int
    let interval: Int
}

struct GitHubTokenResponse: Codable {
    let access_token: String?
    let token_type: String?
    let scope: String?
    let error: String?
    let error_description: String?
}

final class GitHubDeviceFlowService: ObservableObject, @unchecked Sendable {
    static let shared = GitHubDeviceFlowService()
    
    // 这是一个占位 Client ID，实际开发中用户或开发者可以替换它
    private let clientID = "Ov23ctY8Z6X9W2V5U1T0"
    
    private init() {}
    
    func requestDeviceCode() async throws -> GitHubDeviceCodeResponse {
        guard let url = URL(string: "https://github.com/login/device/code") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "client_id": clientID,
            "scope": "repo"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(GitHubDeviceCodeResponse.self, from: data)
    }
    
    func pollForToken(deviceCode: String, interval: Int) async throws -> String {
        guard let url = URL(string: "https://github.com/login/oauth/access_token") else {
            throw URLError(.badURL)
        }
        
        let body: [String: String] = [
            "client_id": clientID,
            "device_code": deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
        ]
        
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let sleepInterval = interval > 0 ? interval : 5
        
        while true {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            let tokenResponse = try JSONDecoder().decode(GitHubTokenResponse.self, from: data)
            
            if let token = tokenResponse.access_token {
                return token
            }
            
            if let error = tokenResponse.error {
                switch error {
                case "authorization_pending":
                    try await Task.sleep(nanoseconds: UInt64(sleepInterval) * 1_000_000_000)
                case "slow_down":
                    try await Task.sleep(nanoseconds: UInt64(sleepInterval + 5) * 1_000_000_000)
                case "expired_token":
                    throw DeviceFlowError.expired
                case "access_denied":
                    throw DeviceFlowError.accessDenied
                default:
                    throw DeviceFlowError.unknown(error)
                }
            } else {
                throw DeviceFlowError.invalidResponse
            }
        }
    }
    
    // MARK: - GitHub API Methods
    
    struct GitHubUserResponse: Codable {
        let login: String
    }

    struct GitHubRepo: Codable, Identifiable, Hashable {
        let id: Int
        let name: String
        let fullName: String
        let cloneUrl: String
        let isPrivate: Bool
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case fullName = "full_name"
            case cloneUrl = "clone_url"
            case isPrivate = "private"
        }
    }

    struct GitHubBranch: Codable {
        let name: String
    }
    
    /// 获取用户信息（用户名）
    func fetchUserInfo(token: String) async throws -> String {
        guard let url = URL(string: "https://api.github.com/user") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("GitReader-App", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let user = try JSONDecoder().decode(GitHubUserResponse.self, from: data)
        return user.login
    }
    
    /// 获取用户仓库列表
    func fetchRepositories(token: String) async throws -> [GitHubRepo] {
        guard let url = URL(string: "https://api.github.com/user/repos?per_page=100&sort=updated") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("GitReader-App", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.userAuthenticationRequired)
        }
        
        return try JSONDecoder().decode([GitHubRepo].self, from: data)
    }
    
    /// 获取仓库分支列表
    func fetchBranches(token: String, owner: String, repo: String) async throws -> [String] {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/branches?per_page=100") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("GitReader-App", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let branches = try JSONDecoder().decode([GitHubBranch].self, from: data)
        return branches.map { $0.name }
    }
}

enum DeviceFlowError: LocalizedError {
    case expired
    case accessDenied
    case invalidResponse
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .expired:
            return "device_flow_expired".localized
        case .accessDenied:
            return "device_flow_access_denied".localized
        case .invalidResponse:
            return "device_flow_invalid_response".localized
        case .unknown(let msg):
            return msg
        }
    }
}
