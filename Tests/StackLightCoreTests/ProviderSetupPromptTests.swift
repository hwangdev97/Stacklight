import XCTest
@testable import StackLightCore

final class ProviderSetupPromptTests: XCTestCase {
    func testIncludesProviderHeaderAndDocsURL() {
        let prompt = ProviderSetupPrompt.prompt(for: ProviderSetupContext(
            providerID: "vercel",
            providerName: "Vercel",
            isConfigured: false,
            docsURL: "https://vercel.com/account/tokens"
        ))

        XCTAssertTrue(prompt.contains("Vercel"))
        XCTAssertTrue(prompt.contains("- ID: vercel"))
        XCTAssertTrue(prompt.contains("Currently configured: no"))
        XCTAssertTrue(prompt.contains("https://vercel.com/account/tokens"))
    }

    func testDescribesFieldsWithMetadataAndPresence() {
        let prompt = ProviderSetupPrompt.prompt(for: ProviderSetupContext(
            providerID: "cloudflare",
            providerName: "Cloudflare Pages",
            isConfigured: true,
            fields: [
                ProviderSetupField(
                    key: "cloudflare.token",
                    label: "API Token",
                    isSecret: true,
                    isMultiValue: false,
                    isPresent: true,
                    kind: "text",
                    placeholder: "Cloudflare API token"
                ),
                ProviderSetupField(
                    key: "cloudflare.projectNames",
                    label: "Project Names",
                    isSecret: false,
                    isMultiValue: true,
                    isPresent: false,
                    kind: "text",
                    hint: "Leave empty to auto-discover all Pages projects"
                )
            ]
        ))

        XCTAssertTrue(prompt.contains("API Token (`cloudflare.token`)"))
        XCTAssertTrue(prompt.contains("secret, stored in the macOS Keychain"))
        XCTAssertTrue(prompt.contains("currently set"))
        XCTAssertTrue(prompt.contains("Example/format: Cloudflare API token"))
        XCTAssertTrue(prompt.contains("Project Names (`cloudflare.projectNames`)"))
        XCTAssertTrue(prompt.contains("multi-value (one entry per row)"))
        XCTAssertTrue(prompt.contains("currently empty"))
        XCTAssertTrue(prompt.contains("Note: Leave empty to auto-discover all Pages projects"))
    }

    func testNeverLeaksFieldValuesAndAlwaysReturnsPrompt() {
        let prompt = ProviderSetupPrompt.prompt(for: ProviderSetupContext(
            providerID: "testFlight",
            providerName: "TestFlight",
            isConfigured: false
        ))

        // No fields supplied — still a usable prompt, with a clear note.
        XCTAssertTrue(prompt.contains("This provider has no configurable fields."))
        XCTAssertTrue(prompt.contains("Open StackLight → Settings → TestFlight"))
        XCTAssertTrue(prompt.contains("click Save and then Test"))
    }

    func testBlankPlaceholderAndHintAreOmitted() {
        let prompt = ProviderSetupPrompt.prompt(for: ProviderSetupContext(
            providerID: "netlify",
            providerName: "Netlify",
            isConfigured: false,
            fields: [
                ProviderSetupField(
                    key: "netlify.token",
                    label: "Personal Access Token",
                    isSecret: true,
                    isMultiValue: false,
                    isPresent: false,
                    kind: "text",
                    placeholder: "   ",
                    hint: ""
                )
            ]
        ))

        XCTAssertFalse(prompt.contains("Example/format:"))
        XCTAssertFalse(prompt.contains("Note:"))
    }
}
