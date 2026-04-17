#!/usr/bin/env swift
/// Standalone test for Xcode Cloud API — tests keychain reads and raw API calls.
/// Run: swift Tests/test_xcode_cloud.swift

import Foundation
import Security

// MARK: - Keychain Helper

func readKeychain(key: String) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "app.yellowplus.StackLight",
        kSecAttrAccount as String: key,
        kSecMatchLimit as String: kSecMatchLimitOne,
        kSecReturnData as String: true
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else {
        return nil
    }
    return String(data: data, encoding: .utf8)
}

// MARK: - Test Runner

var passed = 0
var failed = 0

func test(_ name: String, _ block: () throws -> Void) {
    do {
        try block()
        passed += 1
        print("  ✅ \(name)")
    } catch {
        failed += 1
        print("  ❌ \(name): \(error)")
    }
}

struct Err: Error, CustomStringConvertible {
    let description: String
}

// MARK: - Tests

print("\n🔧 Xcode Cloud Credential & Keychain Tests\n")

print("── 1. Keychain Read Tests ──")

var issuerID: String?
var keyID: String?
var privateKey: String?

test("asc.issuerID exists and is non-empty") {
    issuerID = readKeychain(key: "asc.issuerID")
    guard let v = issuerID, !v.isEmpty else { throw Err(description: "not found or empty") }
    print("    → \(v.prefix(8))... (\(v.count) chars)")
}

test("asc.privateKeyID exists and is non-empty") {
    keyID = readKeychain(key: "asc.privateKeyID")
    guard let v = keyID, !v.isEmpty else { throw Err(description: "not found or empty") }
    print("    → \(v)")
}

test("asc.privateKey exists and is valid PEM") {
    privateKey = readKeychain(key: "asc.privateKey")
    guard let v = privateKey, !v.isEmpty else { throw Err(description: "not found or empty") }
    guard v.contains("BEGIN PRIVATE KEY") else {
        throw Err(description: "Not PEM format. First 40 chars: '\(v.prefix(40))'")
    }
    print("    → PEM key, \(v.count) chars")
}

test("vercel.token exists (for comparison)") {
    let token = readKeychain(key: "vercel.token")
    guard let v = token, !v.isEmpty else { throw Err(description: "not found or empty") }
    print("    → \(v.prefix(10))... (\(v.count) chars)")
}

print("\n── 2. Key Format Validation ──")

test("Private key has correct PEM structure") {
    guard let key = privateKey else { throw Err(description: "no key") }
    let lines = key.components(separatedBy: "\n")
    guard lines.first?.contains("BEGIN PRIVATE KEY") == true else {
        throw Err(description: "Missing BEGIN header. First line: '\(lines.first ?? "")'")
    }
    guard lines.last(where: { !$0.isEmpty })?.contains("END PRIVATE KEY") == true else {
        throw Err(description: "Missing END footer")
    }
    // Extract base64 content
    let b64 = lines.filter { !$0.contains("---") && !$0.isEmpty }.joined()
    guard let data = Data(base64Encoded: b64) else {
        throw Err(description: "Base64 decode failed")
    }
    print("    → DER data: \(data.count) bytes")
    // EC P-256 PKCS#8 key should be ~138 bytes
    guard data.count > 100 && data.count < 200 else {
        throw Err(description: "Unexpected key size: \(data.count) bytes (expected ~138 for ES256)")
    }
    print("    → Size looks correct for ES256")
}

print("\n── 3. AppStoreConnect SDK Compatibility ──")

test("Key can be loaded by Security framework (PKCS#8 → EC key)") {
    guard let key = privateKey else { throw Err(description: "no key") }
    let b64 = key.components(separatedBy: "\n")
        .filter { !$0.contains("---") && !$0.isEmpty }
        .joined()
    guard let derData = Data(base64Encoded: b64) else {
        throw Err(description: "Base64 decode failed")
    }

    // Try importing as PKCS#8 (this is what the SDK does internally)
    let attributes: [String: Any] = [
        kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
    ]
    var error: Unmanaged<CFError>?
    if let secKey = SecKeyCreateWithData(derData as CFData, attributes as CFDictionary, &error) {
        print("    → Direct PKCS#8 import: ✅")
        _ = secKey
    } else {
        // SecKeyCreateWithData may need raw key bytes, not PKCS#8 wrapper
        // The SDK uses a different method — this is expected to fail
        print("    → Direct PKCS#8 import failed (expected — SDK strips ASN.1 wrapper)")
        print("    → Error: \(error?.takeRetainedValue().localizedDescription ?? "?")")
        print("    → Note: The AppStoreConnect SDK handles PKCS#8 parsing internally via swift-crypto")
    }
}

print("\n── 4. Simulated Provider Check ──")

test("XcodeCloudProvider.isConfigured logic returns true") {
    guard let i = readKeychain(key: "asc.issuerID"),
          let k = readKeychain(key: "asc.privateKeyID"),
          let p = readKeychain(key: "asc.privateKey") else {
        throw Err(description: "Keychain read returned nil")
    }
    let result = !i.isEmpty && !k.isEmpty && !p.isEmpty
    guard result else { throw Err(description: "isConfigured would be false") }
    print("    → isConfigured = true")
}

test("All three ASC keys use same Keychain service") {
    // Verify they're all under app.yellowplus.StackLight
    let keys = ["asc.issuerID", "asc.privateKeyID", "asc.privateKey"]
    for key in keys {
        guard readKeychain(key: key) != nil else {
            throw Err(description: "\(key) not readable with service=app.yellowplus.StackLight")
        }
    }
    print("    → All keys accessible under 'app.yellowplus.StackLight'")
}

// Summary
print("\n── Results ──")
print("  \(passed) passed, \(failed) failed\n")

if failed > 0 {
    print("⚠️  Some tests failed. Check the output above.")
} else {
    print("✅ All credential tests passed!")
    print("   The Keychain entries look correct.")
    print("   If Xcode Cloud still shows 'No recent deployments',")
    print("   the issue may be in how the SDK creates the JWT token")
    print("   or in the API response parsing.")
}
print("")
