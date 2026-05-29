import XCTest
@testable import StackLightCore

final class AIErrorHandoffTests: XCTestCase {
    func testReturnsNilWhenThereIsNoErrorContext() {
        let context = AIErrorHandoffContext(
            providerID: "vercel",
            providerName: "Vercel",
            isConfigured: true
        )

        XCTAssertNil(AIErrorHandoff.prompt(for: context))
    }

    func testIncludesTopLevelProviderErrorAndDiagnosticCommand() throws {
        let prompt = try XCTUnwrap(AIErrorHandoff.prompt(for: AIErrorHandoffContext(
            providerID: "githubActions",
            providerName: "GitHub Actions",
            isConfigured: true,
            providerError: "Authorization failed - check token",
            generatedAt: Date(timeIntervalSince1970: 0),
            osVersion: "macOS test"
        )))

        XCTAssertTrue(prompt.contains("GitHub Actions"))
        XCTAssertTrue(prompt.contains("githubActions"))
        XCTAssertTrue(prompt.contains("Authorization failed - check token"))
        XCTAssertTrue(prompt.contains("stacklight test 'githubActions' --json"))
    }

    func testIncludesTestFailureAndPartialItemErrors() throws {
        let prompt = try XCTUnwrap(AIErrorHandoff.prompt(for: AIErrorHandoffContext(
            providerID: "testFlight",
            providerName: "TestFlight",
            isConfigured: true,
            testFailure: "HTTP 403: Forbidden",
            itemErrors: [
                "123": "Not found",
                "456": "Decode error"
            ],
            osVersion: "macOS test"
        )))

        XCTAssertTrue(prompt.contains("Latest Test failure:"))
        XCTAssertTrue(prompt.contains("HTTP 403: Forbidden"))
        XCTAssertTrue(prompt.contains("- 123: Not found"))
        XCTAssertTrue(prompt.contains("- 456: Decode error"))
    }

    func testRedactsFieldValuesAndOnlyReportsPresence() throws {
        let prompt = try XCTUnwrap(AIErrorHandoff.prompt(for: AIErrorHandoffContext(
            providerID: "vercel",
            providerName: "Vercel",
            isConfigured: true,
            providerError: "HTTP 401",
            fields: [
                AIErrorHandoffField(
                    key: "vercel.token",
                    label: "Token",
                    isSecret: true,
                    isPresent: true,
                    isMultiValue: false,
                    kind: "text"
                ),
                AIErrorHandoffField(
                    key: "vercel.teamID",
                    label: "Team ID",
                    isSecret: false,
                    isPresent: false,
                    isMultiValue: false,
                    kind: "text"
                )
            ],
            osVersion: "macOS test"
        )))

        XCTAssertTrue(prompt.contains("Token (`vercel.token`): present, secret"))
        XCTAssertTrue(prompt.contains("Team ID (`vercel.teamID`): missing, non-secret"))
        XCTAssertFalse(prompt.contains("secret-token"))
    }

    func testShellQuotesProviderID() throws {
        let prompt = try XCTUnwrap(AIErrorHandoff.prompt(for: AIErrorHandoffContext(
            providerID: "weird'id",
            providerName: "Weird",
            isConfigured: true,
            providerError: "broken",
            osVersion: "macOS test"
        )))

        XCTAssertTrue(prompt.contains("stacklight test 'weird'\\''id' --json"))
    }
}

