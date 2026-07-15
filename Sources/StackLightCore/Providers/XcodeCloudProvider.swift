import Foundation
import SwiftUI
import AppStoreConnect_Swift_SDK

public final class XcodeCloudProvider: DeploymentProvider {
    public let id = "xcodeCloud"
    public let displayName = "Xcode Cloud"
    public let iconSymbol = "hammer.fill"
    public let iconAsset: String? = "xcode"
    public let color = Color(red: 0.10, green: 0.46, blue: 0.98)
    public let docsURL = URL(string: "https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api")

    // App Store Connect doesn't have a stable per-team dashboard URL without
    // the team ID; land on the apps list which is where Xcode Cloud lives.
    public let dashboardURL: URL? = URL(string: "https://appstoreconnect.apple.com/apps")

    public init() {}

    public var isConfigured: Bool {
        ASCCredentialStore.current() != nil
    }

    public func fetchDeployments() async throws -> DeploymentFetchResult {
        let provider = try makeProvider()

        let productsRequest = APIEndpoint.v1.ciProducts.get(parameters: .init(
            limit: 25,
            include: [.app]
        ))
        let productsResponse = try await provider.request(productsRequest)

        let teamId: String? = {
            let raw = (AppConfig.string(forKey: "asc.teamID") ?? "")
                .trimmingCharacters(in: .whitespaces)
            return raw.isEmpty ? nil : raw
        }()

        var deployments: [Deployment] = []
        var itemErrors: [(item: String, error: Error)] = []
        for product in productsResponse.data {
            let productName = product.attributes?.name ?? "Build"
            let appId = product.relationships?.app?.data?.id
            do {
                let runsRequest = APIEndpoint.v1.ciProducts.id(product.id).buildRuns
                    .get(parameters: .init(
                        sort: [.minusnumber],
                        limit: 5
                    ))
                let runsResponse = try await provider.request(runsRequest)

                let mapped = runsResponse.data.compactMap { run -> Deployment? in
                    guard let attrs = run.attributes else { return nil }
                    let url = appId.flatMap { appId -> URL? in
                        let prefix = teamId.map { "https://appstoreconnect.apple.com/teams/\($0)" }
                            ?? "https://appstoreconnect.apple.com"
                        return URL(string: "\(prefix)/apps/\(appId)/ci/builds/\(run.id)")
                    }
                    return Deployment(
                        id: run.id,
                        providerID: "xcodeCloud",
                        projectName: productName,
                        status: mapStatus(
                            progress: attrs.executionProgress,
                            completion: attrs.completionStatus
                        ),
                        url: url,
                        createdAt: attrs.createdDate ?? Date(),
                        commitMessage: attrs.sourceCommit?.message,
                        branch: nil
                    )
                }
                deployments.append(contentsOf: mapped)
            } catch {
                itemErrors.append((item: productName, error: error))
            }
        }
        return DeploymentFetchResult(deployments: deployments, itemErrors: itemErrors)
    }

    public func settingsFields() -> [SettingsField] {
        [
            SettingsField(key: "asc.issuerID", label: "Issuer ID", isSecret: true, placeholder: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
                          hint: "Users and Access → Integrations → App Store Connect API → Issuer ID (top of page)"),
            SettingsField(key: "asc.privateKeyID", label: "Key ID", isSecret: true, placeholder: "e.g. ABC1234DEF",
                          hint: "Same page → Keys table → Key ID column"),
            SettingsField(key: "asc.privateKey", label: "Private Key (.p8)", isSecret: true, placeholder: "-----BEGIN PRIVATE KEY-----...",
                          hint: "Download the .p8 file when creating the key (one-time only), then paste its contents here"),
            SettingsField(key: "asc.teamID", label: "Team ID", placeholder: "Optional — e.g. 8d8c1bdc-...",
                          hint: "Optional. Copy from any App Store Connect URL: appstoreconnect.apple.com/teams/<this part>/apps/...  Used to build deeplinks to specific build runs.")
        ]
    }

    private func makeProvider() throws -> APIProvider {
        guard let credentials = ASCCredentialStore.current() else {
            throw NSError(domain: "XcodeCloud", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing API credentials — configure in Settings"])
        }
        let config = try APIConfiguration(
            issuerID: credentials.issuerID,
            privateKeyID: credentials.keyID,
            privateKey: credentials.privateKey
        )
        return APIProvider(configuration: config)
    }

    // MARK: - Failure details

    /// Walks the run's actions and collects the `ciIssues` App Store Connect
    /// recorded for each failed one — compile errors, test failures, and the
    /// analyzer/warning noise around them:
    ///   1. `GET /v1/ciBuildRuns/{id}/actions`
    ///   2. per failed action, `GET /v1/ciBuildActions/{id}/issues`
    /// The row's `id` is the native `ciBuildRuns` resource ID, so no
    /// reverse-mapping is needed.
    public func fetchFailureDetails(for deployment: Deployment) async throws -> DeploymentFailureDetails {
        let provider = try makeProvider()

        let actionsRequest = APIEndpoint.v1.ciBuildRuns.id(deployment.id).actions.get()
        let actionsResponse = try await provider.request(actionsRequest)

        let failedActions = actionsResponse.data.filter { action in
            switch action.attributes?.completionStatus {
            case .failed, .errored: return true
            default: return false
            }
        }

        var issues: [DeploymentFailureDetails.Issue] = []
        var errorCount = 0
        var testFailureCount = 0
        for action in failedActions.prefix(3) {
            let actionName = action.attributes?.name
            // Issues are best-effort per action; one 4xx shouldn't hide the rest.
            let issuesRequest = APIEndpoint.v1.ciBuildActions.id(action.id).issues.get(limit: 25)
            guard let issuesResponse = try? await provider.request(issuesRequest) else { continue }

            for ciIssue in issuesResponse.data {
                guard let attributes = ciIssue.attributes else { continue }
                let severity = Self.issueSeverity(for: attributes.issueType?.rawValue)
                // Warnings drown out the signal on big projects; keep errors
                // and test failures, plus warnings only while nothing harder
                // has been collected.
                switch attributes.issueType {
                case .error: errorCount += 1
                case .testFailure: testFailureCount += 1
                default:
                    if !issues.isEmpty { continue }
                }
                let location: String? = {
                    if let path = attributes.fileSource?.path {
                        if let line = attributes.fileSource?.lineNumber {
                            return "\(path):\(line)"
                        }
                        return path
                    }
                    return actionName
                }()
                issues.append(.init(
                    severity: severity,
                    message: String((attributes.message ?? "Unknown issue").prefix(500)),
                    source: location
                ))
            }
        }

        let summary = Self.failureSummary(
            failedActionNames: failedActions.compactMap { $0.attributes?.name },
            errorCount: errorCount,
            testFailureCount: testFailureCount
        )
        return DeploymentFailureDetails(
            summary: summary,
            issues: Array(issues.prefix(8)),
            logsURL: deployment.url
        )
    }

    static func issueSeverity(for issueType: String?) -> DeploymentFailureDetails.Issue.Severity {
        switch issueType {
        case "ERROR", "TEST_FAILURE": return .error
        case "WARNING", "ANALYZER_WARNING": return .warning
        default: return .note
        }
    }

    static func failureSummary(
        failedActionNames: [String],
        errorCount: Int,
        testFailureCount: Int
    ) -> String? {
        var counts: [String] = []
        if errorCount > 0 {
            counts.append(errorCount == 1 ? "1 error" : "\(errorCount) errors")
        }
        if testFailureCount > 0 {
            counts.append(testFailureCount == 1 ? "1 test failure" : "\(testFailureCount) test failures")
        }

        switch (failedActionNames.isEmpty, counts.isEmpty) {
        case (true, true):
            return nil
        case (false, true):
            return "Action “\(failedActionNames[0])” failed"
        case (true, false):
            return "Build failed — " + counts.joined(separator: ", ")
        case (false, false):
            return "“\(failedActionNames[0])” failed — " + counts.joined(separator: ", ")
        }
    }

    private func mapStatus(
        progress: CiExecutionProgress?,
        completion: CiCompletionStatus?
    ) -> Deployment.Status {
        if let progress {
            switch progress {
            case .pending: return .queued
            case .running: return .building
            case .complete: break
            }
        }
        if let completion {
            switch completion {
            case .succeeded: return .success
            case .failed, .errored: return .failed
            case .canceled: return .cancelled
            case .skipped: return .cancelled
            }
        }
        return .unknown
    }
}

extension XcodeCloudProvider: FailureDetailsProviding {}
