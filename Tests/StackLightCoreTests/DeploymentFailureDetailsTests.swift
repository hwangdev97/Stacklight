import XCTest
@testable import StackLightCore

final class DeploymentFailureDetailsTests: XCTestCase {

    // MARK: - tailExcerpt

    func testTailExcerptKeepsShortLogsIntact() {
        let log = "line 1\nline 2\nline 3"
        let (text, truncated) = DeploymentFailureDetails.tailExcerpt(log)
        XCTAssertEqual(text, log)
        XCTAssertFalse(truncated)
    }

    func testTailExcerptKeepsOnlyTheTailLines() {
        let log = (1...100).map { "line \($0)" }.joined(separator: "\n")
        let (text, truncated) = DeploymentFailureDetails.tailExcerpt(log, maxLines: 10)
        XCTAssertTrue(truncated)
        let lines = text.split(separator: "\n")
        XCTAssertEqual(lines.count, 10)
        XCTAssertEqual(lines.first, "line 91")
        XCTAssertEqual(lines.last, "line 100")
    }

    func testTailExcerptHonorsCharacterBudgetWithWholeLines() {
        let log = (1...5).map { "line-\($0)-" + String(repeating: "x", count: 20) }.joined(separator: "\n")
        let (text, truncated) = DeploymentFailureDetails.tailExcerpt(log, maxLines: 10, maxCharacters: 60)
        XCTAssertTrue(truncated)
        // Every kept line must be complete.
        for line in text.split(separator: "\n") {
            XCTAssertTrue(line.hasSuffix(String(repeating: "x", count: 20)))
        }
        XCTAssertTrue(text.contains("line-5-"))
        XCTAssertLessThanOrEqual(text.count, 60)
    }

    func testTailExcerptDropsTrailingBlankLines() {
        let (text, truncated) = DeploymentFailureDetails.tailExcerpt("real output\n\n\n\n")
        XCTAssertEqual(text, "real output")
        XCTAssertFalse(truncated)
    }

    func testTailExcerptStripsANSIEscapes() {
        let log = "\u{1B}[31merror:\u{1B}[0m something broke"
        let (text, _) = DeploymentFailureDetails.tailExcerpt(log)
        XCTAssertEqual(text, "error: something broke")
    }

    func testTailExcerptCollapsesCarriageReturnProgress() {
        let log = "Downloading 10%\rDownloading 55%\rDownloading 100%"
        let (text, _) = DeploymentFailureDetails.tailExcerpt(log)
        XCTAssertEqual(text, "Downloading 100%")
    }

    func testInitNormalizesBlankStringsToNil() {
        let details = DeploymentFailureDetails(summary: "  \n ", logExcerpt: "\n")
        XCTAssertNil(details.summary)
        XCTAssertNil(details.logExcerpt)
        XCTAssertTrue(details.isEmpty)
    }

    // MARK: - Agent prompt

    private func makeDeployment(
        id: String = "dep-1",
        providerID: String = "vercel",
        status: Deployment.Status = .failed
    ) -> Deployment {
        Deployment(
            id: id,
            providerID: providerID,
            projectName: "lofi",
            repository: "hwang/lofi",
            status: status,
            url: URL(string: "https://vercel.com/deployments/dep-1"),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            commitMessage: "fix: audio loop\n\nlong body here",
            branch: "main"
        )
    }

    func testDeploymentPromptIncludesMetadataAndDetails() {
        let details = DeploymentFailureDetails(
            summary: "Build failed — 1 error",
            issues: [
                .init(severity: .error, message: "Cannot find 'Player' in scope", source: "Sources/App.swift:12")
            ],
            logExcerpt: "error: Cannot find 'Player' in scope",
            logExcerptTruncated: true,
            logsURL: URL(string: "https://example.com/logs")
        )
        let prompt = AIErrorHandoff.deploymentPrompt(for: DeploymentErrorHandoffContext(
            deployment: makeDeployment(),
            providerName: "Vercel",
            details: details,
            generatedAt: Date(timeIntervalSince1970: 0),
            appVersion: "1.0"
        ))

        XCTAssertTrue(prompt.contains("Provider: Vercel (vercel)"))
        XCTAssertTrue(prompt.contains("Project: lofi"))
        XCTAssertTrue(prompt.contains("Repository: hwang/lofi"))
        XCTAssertTrue(prompt.contains("Branch: main"))
        // Only the commit subject line, not the body.
        XCTAssertTrue(prompt.contains("Commit: fix: audio loop"))
        XCTAssertFalse(prompt.contains("long body here"))
        XCTAssertTrue(prompt.contains("Build failed — 1 error"))
        XCTAssertTrue(prompt.contains("[error] Cannot find 'Player' in scope (Sources/App.swift:12)"))
        XCTAssertTrue(prompt.contains("(tail — earlier lines truncated)"))
        XCTAssertTrue(prompt.contains("```"))
        XCTAssertTrue(prompt.contains("https://example.com/logs"))
        XCTAssertTrue(prompt.contains("StackLight 1.0"))
        XCTAssertFalse(prompt.contains("No detailed error output was available"))
    }

    func testDeploymentPromptFallsBackToMetadataOnly() {
        let prompt = AIErrorHandoff.deploymentPrompt(for: DeploymentErrorHandoffContext(
            deployment: makeDeployment(providerID: "testFlight"),
            providerName: "TestFlight",
            details: nil
        ))
        XCTAssertTrue(prompt.contains("No detailed error output was available"))
        XCTAssertTrue(prompt.contains("Provider: TestFlight (testFlight)"))
        XCTAssertFalse(prompt.contains("Build log excerpt"))
    }

    // MARK: - FailureDetailsService caching

    private final class CountingSource: FailureDetailsProviding {
        var fetchCount = 0
        var result = DeploymentFailureDetails(summary: "boom")

        func fetchFailureDetails(for deployment: Deployment) async throws -> DeploymentFailureDetails {
            fetchCount += 1
            return result
        }
    }

    func testServiceCachesPerDeployment() async throws {
        let service = FailureDetailsService(ttl: 600)
        let source = CountingSource()
        let deployment = makeDeployment()

        let first = try await service.details(for: deployment, from: source)
        let second = try await service.details(for: deployment, from: source)

        XCTAssertEqual(first.summary, "boom")
        XCTAssertEqual(second, first)
        XCTAssertEqual(source.fetchCount, 1)

        let other = makeDeployment(id: "dep-2")
        _ = try await service.details(for: other, from: source)
        XCTAssertEqual(source.fetchCount, 2)
    }

    func testServiceExpiresCacheAfterTTL() async throws {
        let service = FailureDetailsService(ttl: 0)
        let source = CountingSource()
        let deployment = makeDeployment()

        _ = try await service.details(for: deployment, from: source)
        _ = try await service.details(for: deployment, from: source)
        XCTAssertEqual(source.fetchCount, 2)
    }
}
