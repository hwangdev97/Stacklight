import XCTest
@testable import StackLightCore

/// Tests for the per-provider mapping from upstream error/log payloads into
/// `DeploymentFailureDetails`, including decoding of the wire formats.
final class ProviderFailureDetailsTests: XCTestCase {

    // MARK: - Vercel

    func testVercelEventDecodingHandlesBothTextShapes() throws {
        let json = """
        [
          {"type": "stderr", "created": 2, "payload": {"text": "npm ERR! missing script build"}},
          {"type": "stdout", "created": 1, "text": "Installing dependencies..."},
          {"type": "deployment-state", "created": 3}
        ]
        """
        let events = try SharedJSON.decoder.decode([VercelBuildEvent].self, from: Data(json.utf8))
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0].logText, "npm ERR! missing script build")
        XCTAssertEqual(events[1].logText, "Installing dependencies...")
        XCTAssertNil(events[2].logText)
    }

    func testVercelFailureDetailsRestoresChronologicalOrderAndFindsSummary() throws {
        // Backward order (newest first), as fetched with direction=backward.
        let events = [
            VercelBuildEvent(type: "stderr", created: 3, text: nil, payload: .init(text: "Error: Command \"npm run build\" exited with 1")),
            VercelBuildEvent(type: "stdout", created: 2, text: "> next build", payload: nil),
            VercelBuildEvent(type: "command", created: 1, text: "npm run build", payload: nil),
            VercelBuildEvent(type: "deployment-state", created: 0, text: "ignored", payload: nil)
        ]
        let details = VercelProvider.failureDetails(fromBackwardEvents: events)

        let excerpt = try XCTUnwrap(details.logExcerpt)
        let lines = excerpt.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines, [
            "$ npm run build",
            "> next build",
            "Error: Command \"npm run build\" exited with 1"
        ])
        XCTAssertEqual(details.summary, "Error: Command \"npm run build\" exited with 1")
        XCTAssertFalse(details.isEmpty)
    }

    func testVercelFailureDetailsWithNoLogEventsIsEmpty() {
        let details = VercelProvider.failureDetails(fromBackwardEvents: [])
        XCTAssertTrue(details.isEmpty)
    }

    // MARK: - GitHub Actions

    func testGitHubRunCoordinatesParsedFromRowURL() throws {
        let deployment = Deployment(
            id: "gh-123456",
            providerID: "githubActions",
            projectName: "CI",
            repository: "stacklight",
            status: .failed,
            url: URL(string: "https://github.com/hwangdev97/Stacklight/actions/runs/123456"),
            createdAt: Date(),
            commitMessage: nil,
            branch: "main"
        )
        let coordinates = try XCTUnwrap(GitHubActionsProvider.runCoordinates(for: deployment))
        XCTAssertEqual(coordinates.ownerRepo, "hwangdev97/Stacklight")
        XCTAssertEqual(coordinates.runID, "123456")
    }

    func testGitHubRunCoordinatesRejectsForeignURLs() {
        let deployment = Deployment(
            id: "gh-1", providerID: "githubActions", projectName: "CI",
            status: .failed, url: URL(string: "https://github.com/owner/repo/pull/3"),
            createdAt: Date(), commitMessage: nil, branch: nil
        )
        XCTAssertNil(GitHubActionsProvider.runCoordinates(for: deployment))
    }

    func testGitHubJobsAndAnnotationsDecoding() throws {
        let jobsJSON = """
        {
          "total_count": 2,
          "jobs": [
            {"id": 11, "name": "build", "status": "completed", "conclusion": "failure",
             "html_url": "https://github.com/o/r/actions/runs/1/job/11",
             "steps": [
               {"name": "Checkout", "status": "completed", "conclusion": "success", "number": 1},
               {"name": "Run tests", "status": "completed", "conclusion": "failure", "number": 2}
             ]},
            {"id": 12, "name": "lint", "status": "completed", "conclusion": "success", "steps": []}
          ]
        }
        """
        let response = try SharedJSON.decoder.decode(GHJobsResponse.self, from: Data(jobsJSON.utf8))
        XCTAssertEqual(response.jobs.count, 2)
        XCTAssertTrue(response.jobs[0].isFailed)
        XCTAssertEqual(response.jobs[0].firstFailedStepName, "Run tests")
        XCTAssertFalse(response.jobs[1].isFailed)

        let annotationsJSON = """
        [
          {"path": "src/main.swift", "start_line": 42, "end_line": 42,
           "annotation_level": "failure", "title": "error",
           "message": "cannot find 'foo' in scope"},
          {"path": ".github", "start_line": 0, "annotation_level": "notice", "message": "noise"}
        ]
        """
        let annotations = try SharedJSON.decoder.decode([GHAnnotation].self, from: Data(annotationsJSON.utf8))
        XCTAssertEqual(annotations.count, 2)
        XCTAssertTrue(annotations[0].isRelevant)
        XCTAssertFalse(annotations[1].isRelevant)

        let details = GitHubActionsProvider.failureDetails(
            jobs: response.jobs,
            annotationsByJob: [11: annotations]
        )
        XCTAssertEqual(details.summary, "Job “build” failed at step “Run tests”")
        XCTAssertEqual(details.issues.count, 1)
        XCTAssertEqual(details.issues[0].message, "cannot find 'foo' in scope")
        XCTAssertEqual(details.issues[0].source, "src/main.swift:42")
        XCTAssertEqual(details.logsURL?.absoluteString, "https://github.com/o/r/actions/runs/1/job/11")
    }

    func testGitHubMultipleFailedJobsSummary() {
        let jobs = [
            GHJob(id: 1, name: "build-macos", status: "completed", conclusion: "failure", html_url: nil, steps: nil),
            GHJob(id: 2, name: "build-ios", status: "completed", conclusion: "timed_out", html_url: nil, steps: nil),
            GHJob(id: 3, name: "lint", status: "completed", conclusion: "success", html_url: nil, steps: nil)
        ]
        let details = GitHubActionsProvider.failureDetails(jobs: jobs, annotationsByJob: [:])
        XCTAssertEqual(details.summary, "2 of 3 jobs failed")
        // Per-job issues are emitted when several jobs fail.
        XCTAssertEqual(details.issues.map(\.source), ["build-macos", "build-ios"])
    }

    // MARK: - Cloudflare Pages

    func testCloudflareLogsDecodingAndSummary() throws {
        let json = """
        {
          "success": true,
          "result": {
            "total": 3,
            "includes_container_logs": true,
            "data": [
              {"ts": "2026-01-01T00:00:00Z", "line": "Installing dependencies"},
              {"ts": "2026-01-01T00:00:01Z", "line": "Failed: build command exited with code: 1"},
              {"ts": "2026-01-01T00:00:02Z", "line": ""}
            ]
          }
        }
        """
        let response = try SharedJSON.decoder.decode(CFDeploymentLogsResponse.self, from: Data(json.utf8))
        let details = CloudflareProvider.failureDetails(
            logLines: response.result.data.map(\.line),
            failedStage: "build"
        )
        XCTAssertEqual(details.summary, "Failed: build command exited with code: 1")
        XCTAssertTrue(details.logExcerpt?.contains("Installing dependencies") ?? false)
    }

    func testCloudflareFallsBackToStageSummary() {
        let details = CloudflareProvider.failureDetails(
            logLines: ["Cloning repository", "Done"],
            failedStage: "deploy"
        )
        XCTAssertEqual(details.summary, "Deployment failed during the “deploy” stage")
    }

    // MARK: - Netlify

    func testNetlifyFailureDetailsFromDeployDetail() throws {
        let json = """
        {"id": "abc123", "state": "error",
         "error_message": "Build script returned non-zero exit code: 2",
         "admin_url": "https://app.netlify.com/sites/my-site"}
        """
        let detail = try SharedJSON.decoder.decode(NetlifyDeployDetail.self, from: Data(json.utf8))
        let details = NetlifyProvider.failureDetails(from: detail, deployID: "abc123")
        XCTAssertEqual(details.summary, "Build script returned non-zero exit code: 2")
        XCTAssertEqual(details.logsURL?.absoluteString, "https://app.netlify.com/sites/my-site/deploys/abc123")
    }

    // MARK: - GitLab CI

    func testGitLabPipelineCoordinatesSurviveDashesInProjectPath() throws {
        let deployment = Deployment(
            id: "gl-pipeline-group/sub-group/my-app-987",
            providerID: "gitlabCI", projectName: "my-app",
            status: .failed, url: nil, createdAt: Date(),
            commitMessage: nil, branch: nil
        )
        let coordinates = try XCTUnwrap(GitLabCIProvider.pipelineCoordinates(for: deployment))
        XCTAssertEqual(coordinates.project, "group/sub-group/my-app")
        XCTAssertEqual(coordinates.pipelineID, "987")

        let bogus = Deployment(
            id: "gl-mr-something-1", providerID: "gitlabMR", projectName: "x",
            status: .failed, url: nil, createdAt: Date(), commitMessage: nil, branch: nil
        )
        XCTAssertNil(GitLabCIProvider.pipelineCoordinates(for: bogus))
    }

    func testGitLabFailureDetailsSkipsAllowedFailuresAndSections() throws {
        let jobsJSON = """
        [
          {"id": 5, "name": "unit-tests", "stage": "test", "status": "failed",
           "failure_reason": "script_failure", "allow_failure": false,
           "web_url": "https://gitlab.com/g/p/-/jobs/5"},
          {"id": 6, "name": "lint", "stage": "test", "status": "failed",
           "failure_reason": "script_failure", "allow_failure": true, "web_url": null}
        ]
        """
        let jobs = try SharedJSON.decoder.decode([GLJob].self, from: Data(jobsJSON.utf8))
        let trace = "section_start:123:step_script\n$ swift test\nerror: test failed\nsection_end:123:step_script"
        let details = GitLabCIProvider.failureDetails(jobs: jobs, trace: trace)

        XCTAssertEqual(details.summary, "Job “unit-tests” failed (script failure)")
        XCTAssertEqual(details.issues.count, 1)
        XCTAssertEqual(details.issues[0].source, "stage: test")
        let excerpt = try XCTUnwrap(details.logExcerpt)
        XCTAssertFalse(excerpt.contains("section_start"))
        XCTAssertTrue(excerpt.contains("error: test failed"))
        XCTAssertEqual(details.logsURL?.absoluteString, "https://gitlab.com/g/p/-/jobs/5")
    }

    func testGitLabNoHardFailuresYieldsEmptyDetails() {
        let jobs = [
            GLJob(id: 1, name: "lint", stage: "test", status: "failed",
                  failure_reason: nil, allow_failure: true, web_url: nil)
        ]
        XCTAssertTrue(GitLabCIProvider.failureDetails(jobs: jobs, trace: nil).isEmpty)
    }

    // MARK: - Railway

    func testRailwayLogsDecodingAndSummary() throws {
        let json = """
        {"data": {"buildLogs": [
          {"timestamp": "2026-01-01T00:00:00Z", "message": "Building image...", "severity": "info"},
          {"timestamp": "2026-01-01T00:00:01Z", "message": "npm ERR! code ELIFECYCLE", "severity": "err"}
        ]}}
        """
        let response = try SharedJSON.decoder.decode(RailwayLogsResponse.self, from: Data(json.utf8))
        let logs = try XCTUnwrap(response.data?.buildLogs)
        let details = RailwayProvider.failureDetails(from: logs)
        XCTAssertEqual(details.summary, "npm ERR! code ELIFECYCLE")
        XCTAssertTrue(details.logExcerpt?.contains("Building image...") ?? false)
    }

    // MARK: - Xcode Cloud

    func testXcodeCloudSeverityMapping() {
        XCTAssertEqual(XcodeCloudProvider.issueSeverity(for: "ERROR"), .error)
        XCTAssertEqual(XcodeCloudProvider.issueSeverity(for: "TEST_FAILURE"), .error)
        XCTAssertEqual(XcodeCloudProvider.issueSeverity(for: "WARNING"), .warning)
        XCTAssertEqual(XcodeCloudProvider.issueSeverity(for: "ANALYZER_WARNING"), .warning)
        XCTAssertEqual(XcodeCloudProvider.issueSeverity(for: nil), .note)
    }

    func testXcodeCloudSummaryComposition() {
        XCTAssertNil(XcodeCloudProvider.failureSummary(failedActionNames: [], errorCount: 0, testFailureCount: 0))
        XCTAssertEqual(
            XcodeCloudProvider.failureSummary(failedActionNames: ["Archive iOS"], errorCount: 0, testFailureCount: 0),
            "Action “Archive iOS” failed"
        )
        XCTAssertEqual(
            XcodeCloudProvider.failureSummary(failedActionNames: [], errorCount: 2, testFailureCount: 1),
            "Build failed — 2 errors, 1 test failure"
        )
        XCTAssertEqual(
            XcodeCloudProvider.failureSummary(failedActionNames: ["Test macOS"], errorCount: 1, testFailureCount: 0),
            "“Test macOS” failed — 1 error"
        )
    }
}
