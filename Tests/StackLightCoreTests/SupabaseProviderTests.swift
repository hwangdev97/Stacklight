import XCTest
@testable import StackLightCore

final class SupabaseProviderTests: XCTestCase {
    func testProjectRefsAreNormalizedAndDeduplicated() {
        let refs = SupabaseProvider.parseProjectRefs(" ABCDEFGHIJKLMNOPQRST , abcdefghijklmnopqrst, zyxwvutsrqponmlkjihg ")

        XCTAssertEqual(refs, [
            "abcdefghijklmnopqrst",
            "zyxwvutsrqponmlkjihg"
        ])
    }

    func testProjectStatusMapping() {
        XCTAssertEqual(SupabaseStatusMapper.projectStatus("ACTIVE_HEALTHY"), .success)
        XCTAssertEqual(SupabaseStatusMapper.projectStatus("COMING_UP"), .building)
        XCTAssertEqual(SupabaseStatusMapper.projectStatus("RESTARTING"), .building)
        XCTAssertEqual(SupabaseStatusMapper.projectStatus("INACTIVE"), .cancelled)
        XCTAssertEqual(SupabaseStatusMapper.projectStatus("INIT_FAILED"), .failed)
        XCTAssertEqual(SupabaseStatusMapper.projectStatus("SOMETHING_NEW"), .unknown)
    }

    func testServiceHealthOverridesProjectStatus() {
        let unhealthy = SupabaseServiceHealth(name: "db", healthy: true, status: "UNHEALTHY")
        let comingUp = SupabaseServiceHealth(name: "rest", healthy: true, status: "COMING_UP")

        XCTAssertEqual(
            SupabaseStatusMapper.combinedProjectStatus(projectStatus: "ACTIVE_HEALTHY", health: [unhealthy]),
            .failed
        )
        XCTAssertEqual(
            SupabaseStatusMapper.combinedProjectStatus(projectStatus: "ACTIVE_HEALTHY", health: [comingUp]),
            .building
        )
    }

    func testBranchStatusPrefersPreviewProjectStatus() {
        XCTAssertEqual(
            SupabaseStatusMapper.branchStatus(status: "MIGRATIONS_FAILED", previewProjectStatus: "ACTIVE_HEALTHY"),
            .success
        )
        XCTAssertEqual(
            SupabaseStatusMapper.branchStatus(status: "MIGRATIONS_FAILED", previewProjectStatus: nil),
            .failed
        )
    }

    func testActionStatusMapping() {
        XCTAssertEqual(
            SupabaseStatusMapper.actionStatus([.init(name: "deploy", status: "RUNNING")]),
            .building
        )
        XCTAssertEqual(
            SupabaseStatusMapper.actionStatus([.init(name: "deploy", status: "DEAD")]),
            .failed
        )
        XCTAssertEqual(
            SupabaseStatusMapper.actionStatus([.init(name: "deploy", status: "CREATED")]),
            .queued
        )
        XCTAssertEqual(
            SupabaseStatusMapper.actionStatus([.init(name: "deploy", status: "EXITED")]),
            .success
        )
    }
}
