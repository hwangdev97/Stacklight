import Foundation

/// Caches the three App Store Connect API credentials so Xcode Cloud /
/// TestFlight providers don't trigger three separate Keychain reads on every
/// poll. Invalidated explicitly from the Settings UI whenever the user saves
/// or clears a credential field.
public enum ASCCredentialStore {
    public struct Credentials {
        public let issuerID: String
        public let keyID: String
        /// Base64 key content with PEM header/footer and whitespace stripped,
        /// ready to hand to `APIConfiguration`.
        public let privateKey: String

        public init(issuerID: String, keyID: String, privateKey: String) {
            self.issuerID = issuerID
            self.keyID = keyID
            self.privateKey = privateKey
        }
    }

    private static let lock = NSLock()
    private static var cached: Credentials?

    public static func current() -> Credentials? {
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

    public static func invalidate() {
        lock.lock()
        cached = nil
        lock.unlock()
    }
}
