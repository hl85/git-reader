import Foundation

struct GitLabDeviceCodeResponse: Codable {
    let device_code: String
    let user_code: String
    let verification_uri: String
    let expires_in: Int
    let interval: Int
}

struct GitLabTokenResponse: Codable {
    let access_token: String?
    let token_type: String?
    let refresh_token: String?
    let scope: String?
    let error: String?
    let error_description: String?
}

final class GitLabDeviceFlowService: ObservableObject {
    static let shared = GitLabDeviceFlowService()
    
    // 这是一个针对 gitlab.com 官方云端的占位 Client ID
    private let defaultClientID = "gl_client_id_placeholder"
    
    private init() {}
    
    /// 获取规范化的基础 URL
    private func getBaseURL(from serverURL: String?) -> URL? {
        let host = serverURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "https://gitlab.com"
        var urlString = host
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        return URL(string: urlString)
    }
    
    func requestDeviceCode(serverURL: String? = nil, customClientID: String? = nil) async throws -> GitLabDeviceCodeResponse {
        guard let baseURL = getBaseURL(from: serverURL),
              let url = URL(string: "/oauth/authorize_device", relativeTo: baseURL) else {
            throw URLError(.badURL)
        }
        
        let clientID = customClientID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? customClientID! : defaultClientID
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "client_id": clientID,
            "scope": "api read_repository write_repository"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(GitLabDeviceCodeResponse.self, from: data)
    }
    
    func pollForToken(serverURL: String? = nil, customClientID: String? = nil, deviceCode: String, interval: Int) async throws -> String {
        guard let baseURL = getBaseURL(from: serverURL),
              let url = URL(string: "/oauth/token", relativeTo: baseURL) else {
            throw URLError(.badURL)
        }
        
        let clientID = customClientID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? customClientID! : defaultClientID
        
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
            
            let tokenResponse = try JSONDecoder().decode(GitLabTokenResponse.self, from: data)
            
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
}
