import Foundation

/// Caches the three App Store Connect API credentials so Xcode Cloud /
/// TestFlight providers don't trigger three separate Keychain reads on every
/// poll. Invalidated explicitly from the Settings UI whenever the user saves
/// or clears a credential field.
enum ASCCredentialStore {
    struct Credentials {
        let issuerID: String
        let keyID: String
        /// Base64 key content with PEM header/footer and whitespace stripped,
        /// ready to hand to `APIConfiguration`.
        let privateKey: String
    }

    private static let lock = NSLock()
    private static var cached: Credentials?

    static func current() -> Credentials? {
        lock.lock()
        defer { lock.unlock() }
        if let cached {
            return cached
        }
        guard let issuerID = KeychainManager.read(key: "asc.issuerID"),
              let keyID = KeychainManager.read(key: "asc.privateKeyID"),
              let rawKey = KeychainManager.read(key: "asc.privateKey"),
              !issuerID.isEmpty, !keyID.isEmpty, !rawKey.isEmpty else {
            return nil
        }
        let stripped = rawKey
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespaces)
        let credentials = Credentials(issuerID: issuerID, keyID: keyID, privateKey: stripped)
        cached = credentials
        return credentials
    }

    static func invalidate() {
        lock.lock()
        cached = nil
        lock.unlock()
    }
}
