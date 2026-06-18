import Foundation
import Security

/// Keychain 安全凭证管理
/// 使用 kSecClassInternetPassword 存储 Personal Access Token
final class KeychainService {
    static let shared = KeychainService()

    private let service = "com.gitreader.pat"
    private let account = "personal-access-token"

    private init() {}

    /// 写入 PAT 到 Keychain
    func saveToken(_ token: String) throws {
        // 先尝试删除旧数据
        deleteToken()

        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    /// 从 Keychain 读取 PAT
    func readToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    /// 从 Keychain 删除 PAT
    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

public enum KeychainError: LocalizedError {
    case saveFailed(status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain 存储失败 (OSStatus: \(status))"
        }
    }
}
