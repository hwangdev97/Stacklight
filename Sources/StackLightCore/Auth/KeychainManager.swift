import Foundation
import Security

public enum KeychainError: Error {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
}

public enum KeychainManager {
    private static let service = "app.yellowplus.StackLight"

    /// Optional keychain access group. When non-nil, all queries include
    /// `kSecAttrAccessGroup` so the host app and extensions can share items.
    /// macOS leaves this nil and keeps its current per-app scope.
    public static var accessGroup: String?

    private static func baseQuery(key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true
        ]
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }

    public static func save(key: String, value: String) throws {
        let data = Data(value.utf8)

        // Delete existing item first (query without value data)
        SecItemDelete(baseQuery(key: key) as CFDictionary)

        // Add new item. Data Protection Keychain + AfterFirstUnlock gives us
        // per-app scoped storage with no ACL prompts on read.
        var addQuery = baseQuery(key: key)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    public static func read(key: String) -> String? {
        var query = baseQuery(key: key)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public static func delete(key: String) {
        SecItemDelete(baseQuery(key: key) as CFDictionary)
    }
}
