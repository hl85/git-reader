import Foundation
import Security

/// Keychain 安全凭证管理
/// 使用 kSecClassGenericPassword 存储 Personal Access Token
final class KeychainService: @unchecked Sendable {
    static let shared = KeychainService()

    private let service = "com.gitsreader.pat"
    private let account = "personal-access-token"

    private init() {}

    /// 写入 PAT 到 Keychain
    func saveToken(_ token: String, forAccountID accountID: UUID? = nil) throws {
        let accountKey = accountID?.uuidString ?? account
        
        // 先尝试删除旧数据
        deleteToken(forAccountID: accountID)

        guard let data = token.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    /// 从 Keychain 读取 PAT
    func readToken(forAccountID accountID: UUID? = nil) -> String? {
        let accountKey = accountID?.uuidString ?? account
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
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
    func deleteToken(forAccountID accountID: UUID? = nil) {
        let accountKey = accountID?.uuidString ?? account
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(status: OSStatus)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown"
            return "keychain_save_failed".localized(arguments: message, Int32(status))
        case .encodingFailed:
            return "token_encoding_failed".localized
        }
    }
}
