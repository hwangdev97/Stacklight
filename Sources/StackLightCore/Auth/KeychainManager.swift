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

    /// In-memory cache layered over the system Keychain. Every provider's
    /// `isConfigured` calls `read(key:)`, so a 9-provider Settings sidebar
    /// previously triggered ~9 Security framework round-trips per redraw.
    /// We're the only writer for these keys, so memoizing the value (and
    /// invalidating on save/delete) is safe and cuts cold reads on hot paths
    /// down to one per process.
    private static let cacheLock = NSLock()
    private static var cachedValues: [String: String] = [:]
    private static var knownAbsentKeys: Set<String> = []

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
        cacheLock.lock()
        cachedValues[key] = value
        knownAbsentKeys.remove(key)
        cacheLock.unlock()
    }

    public static func read(key: String) -> String? {
        cacheLock.lock()
        if let cached = cachedValues[key] {
            cacheLock.unlock()
            return cached
        }
        if knownAbsentKeys.contains(key) {
            cacheLock.unlock()
            return nil
        }
        cacheLock.unlock()

        var query = baseQuery(key: key)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        let value: String? = {
            guard status == errSecSuccess, let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }()

        cacheLock.lock()
        if let value {
            cachedValues[key] = value
        } else {
            knownAbsentKeys.insert(key)
        }
        cacheLock.unlock()
        return value
    }

    public static func delete(key: String) {
        SecItemDelete(baseQuery(key: key) as CFDictionary)
        cacheLock.lock()
        cachedValues.removeValue(forKey: key)
        knownAbsentKeys.insert(key)
        cacheLock.unlock()
    }

    /// Drops every memoized value. Used by tests and as a safety hatch when
    /// the access group changes — not exercised on the normal hot path.
    public static func clearCache() {
        cacheLock.lock()
        cachedValues.removeAll()
        knownAbsentKeys.removeAll()
        cacheLock.unlock()
    }
}
