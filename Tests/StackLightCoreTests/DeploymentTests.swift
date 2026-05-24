import XCTest
@testable import StackLightCore

final class DeploymentProjectGroupingKeyTests: XCTestCase {
    private func make(projectName: String, repository: String?) -> Deployment {
        Deployment(
            id: "id",
            providerID: "p",
            projectName: projectName,
            repository: repository,
            status: .success,
            url: nil,
            createdAt: Date(),
            commitMessage: nil,
            branch: nil
        )
    }

    func testUsesRepositoryLastSegmentLowercased() {
        let d = make(projectName: "CI", repository: "Owner/StackLight")
        XCTAssertEqual(d.projectGroupingKey, "stacklight")
    }

    func testBareRepositoryIsLowercased() {
        let d = make(projectName: "Release", repository: "StackLight")
        XCTAssertEqual(d.projectGroupingKey, "stacklight")
    }

    func testFallsBackToNormalizedProjectNameWhenNoRepository() {
        let d = make(projectName: "  Marketing-Site  ", repository: nil)
        XCTAssertEqual(d.projectGroupingKey, "marketing-site")
    }

    func testEmptyRepositoryFallsBackToProjectName() {
        let d = make(projectName: "blog", repository: "")
        XCTAssertEqual(d.projectGroupingKey, "blog")
    }

    func testRepoAndProjectNameConvergeForCrossPlatformMatch() {
        // A GitHub repo row and a name-only Vercel row for the same project
        // should land in the same group.
        let ci = make(projectName: "CI", repository: "acme/blog")
        let preview = make(projectName: "Blog", repository: nil)
        XCTAssertEqual(ci.projectGroupingKey, preview.projectGroupingKey)
    }
}
