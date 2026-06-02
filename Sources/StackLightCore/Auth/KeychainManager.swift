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

    /// Whether to file items in the Data Protection Keychain.
    ///
    /// iOS/watchOS always do. On macOS the choice matters: the shipping app is
    /// sandboxed and App Store-distributed, and a sandboxed app gets an
    /// automatic, code-signature-independent access group in the Data
    /// Protection Keychain — exactly what we want. The *legacy* file-based
    /// keychain instead scopes each item with an ACL tied to the creating
    /// binary's signature, so a re-signed build (e.g. a TestFlight/App Store
    /// update vs. a previous local build) can no longer read items it didn't
    /// write, and `read` silently returns nil — making Xcode Cloud/TestFlight
    /// (and any keychain-backed provider) look unconfigured.
    ///
    /// We therefore use the Data Protection Keychain whenever we're sandboxed,
    /// and fall back to the legacy keychain only for unsigned local `swift run`
    /// dev builds, where Data Protection writes fail with errSecMissingEntitlement.
    private static var useDataProtectionKeychain: Bool {
        #if os(macOS)
        return ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        #else
        return true
        #endif
    }

    private static func baseQuery(key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        if useDataProtectionKeychain {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }

    public static func save(key: String, value: String) throws {
        let data = Data(value.utf8)

        // Delete existing item first (query without value data)
        SecItemDelete(baseQuery(key: key) as CFDictionary)

        // Add new item. iOS/watchOS use the Data Protection Keychain; macOS
        // uses the login keychain so unsigned/local builds don't require
        // Keychain Sharing entitlements.
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
        } else if status == errSecItemNotFound {
            // Only memoize a *confirmed* absence. Any other status (e.g. an
            // ACL/permission failure, or a locked keychain) is transient or
            // recoverable — caching it as absent would hide the credential for
            // the rest of the process lifetime even after the condition clears.
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
