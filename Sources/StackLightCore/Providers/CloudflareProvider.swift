import Foundation
import SwiftUI

public final class CloudflareProvider: DeploymentProvider {
    public let id = "cloudflare"
    public let displayName = "Cloudflare Pages"
    public let iconSymbol = "cloud.fill"
    public let color = Color(red: 0.96, green: 0.50, blue: 0.13)
    public let docsURL = URL(string: "https://dash.cloudflare.com/profile/api-tokens")

    public init() {}

    public var dashboardURL: URL? {
        if let accountId = AppConfig.string(forKey: "cloudflare.accountId"), !accountId.isEmpty {
            return URL(string: "https://dash.cloudflare.com/\(accountId)/workers-and-pages")
        }
        return URL(string: "https://dash.cloudflare.com")
    }

    public var isConfigured: Bool {
        guard let token = KeychainManager.read(key: "cloudflare.token"),
              let accountId = AppConfig.string(forKey: "cloudflare.accountId") else {
            return false
        }
        return !token.isEmpty && !accountId.isEmpty
    }

    public func fetchDeployments() async throws -> DeploymentFetchResult {
        guard let token = KeychainManager.read(key: "cloudflare.token"),
              let accountId = AppConfig.string(forKey: "cloudflare.accountId") else {
            return .empty
        }

        var projectNames = AppConfig.string(forKey: "cloudflare.projectNames")?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty } ?? []

        // If no project names specified, auto-discover all Pages projects.
        // A discovery failure here is whole-provider (no list to fan out over),
        // so let it propagate as a top-level throw.
        if projectNames.isEmpty {
            projectNames = try await fetchProjectNames(token: token, accountId: accountId)
        }
        guard !projectNames.isEmpty else { return .empty }

        return await DeploymentFetchResult.collecting(projectNames, name: { $0 }) { projectName in
            try await Self.fetchProjectDeployments(
                token: token, accountId: accountId, projectName: projectName
            )
        }
    }

    public func settingsFields() -> [SettingsField] {
        [
            SettingsField(key: "cloudflare.token", label: "API Token", isSecret: true, placeholder: "Cloudflare API token"),
            SettingsField(key: "cloudflare.accountId", label: "Account ID", placeholder: "32-character hex string", hint: "Found in your dashboard URL: dash.cloudflare.com/<account-id>"),
            SettingsField(key: "cloudflare.projectNames", label: "Project Names", placeholder: "Comma-separated: my-site, docs",
                          hint: "Leave empty to auto-discover all Pages projects")
        ]
    }

    private func fetchProjectNames(token: String, accountId: String) async throws -> [String] {
        let urlString = "https://api.cloudflare.com/client/v4/accounts/\(accountId)/pages/projects"
        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await RequestRunner.shared.get(url: url, token: token)
        let response = try SharedJSON.decoder.decode(CFProjectsResponse.self, from: data)
        return response.result.map(\.name)
    }

    private static func fetchProjectDeployments(token: String, accountId: String, projectName: String) async throws -> [Deployment] {
        let urlString = "https://api.cloudflare.com/client/v4/accounts/\(accountId)/pages/projects/\(projectName)/deployments"
        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await RequestRunner.shared.get(url: url, token: token)
        let response = try SharedJSON.decoder.decode(CFResponse.self, from: data)
        return response.result.prefix(5).map { $0.toDeployment(projectName: projectName) }
    }
}

// MARK: - Failure details

extension CloudflareProvider: FailureDetailsProviding {
    /// Two cheap calls: the deployment detail (for the failing stage name)
    /// and `…/history/logs` (for the build log tail). The Pages row carries
    /// the CF project name in `projectName` and the native deployment ID in
    /// `id`, so no reverse-mapping is needed.
    public func fetchFailureDetails(for deployment: Deployment) async throws -> DeploymentFailureDetails {
        guard let token = KeychainManager.read(key: "cloudflare.token"),
              let accountId = AppConfig.string(forKey: "cloudflare.accountId") else {
            throw ProviderError.unauthorized(message: "Cloudflare credentials missing")
        }

        let base = "https://api.cloudflare.com/client/v4/accounts/\(accountId)/pages/projects/\(deployment.projectName)/deployments/\(deployment.id)"

        // Stage info is nice-to-have; the log tail is the substance. Fetch the
        // detail best-effort and let a failure there degrade to log-only.
        var failedStage: String?
        if let detailURL = URL(string: base),
           let (detailData, _) = try? await RequestRunner.shared.get(url: detailURL, token: token),
           let detail = try? SharedJSON.decoder.decode(CFDeploymentDetailResponse.self, from: detailData) {
            let stage = detail.result.latest_stage
            if stage?.status?.lowercased() == "failure" {
                failedStage = stage?.name
            }
        }

        guard let logsURL = URL(string: "\(base)/history/logs") else {
            return DeploymentFailureDetails()
        }
        let (data, _) = try await RequestRunner.shared.get(url: logsURL, token: token)
        let logs = try SharedJSON.decoder.decode(CFDeploymentLogsResponse.self, from: data)

        return Self.failureDetails(logLines: logs.result.data.map(\.line), failedStage: failedStage)
    }

    static func failureDetails(logLines: [String], failedStage: String?) -> DeploymentFailureDetails {
        let joined = logLines.joined(separator: "\n")
        let (excerpt, truncated) = DeploymentFailureDetails.tailExcerpt(joined)

        // Pages emits explicit "Failed: …" lines on build errors — prefer the
        // last one as the headline, else fall back to the stage name.
        let failureLine = logLines.reversed().first {
            $0.hasPrefix("Failed") || $0.lowercased().contains("error")
        }
        let summary = failureLine.map { String($0.prefix(200)) }
            ?? failedStage.map { "Deployment failed during the “\($0)” stage" }

        return DeploymentFailureDetails(
            summary: summary,
            logExcerpt: excerpt.isEmpty ? nil : excerpt,
            logExcerptTruncated: truncated
        )
    }
}

struct CFDeploymentLogsResponse: Decodable {
    let result: CFDeploymentLog

    struct CFDeploymentLog: Decodable {
        let data: [CFLogLine]
    }

    struct CFLogLine: Decodable {
        let ts: String?
        let line: String
    }
}

private struct CFDeploymentDetailResponse: Decodable {
    let result: CFDeploymentDetail

    struct CFDeploymentDetail: Decodable {
        let latest_stage: CFDeployment.CFStage?
    }
}

// MARK: - API Response Models

private struct CFProjectsResponse: Decodable {
    let result: [CFProject]
    struct CFProject: Decodable {
        let name: String
    }
}

private struct CFResponse: Decodable {
    let result: [CFDeployment]
}

private struct CFDeployment: Decodable {
    let id: String
    let url: String?
    let environment: String?
    let deployment_trigger: CFTrigger?
    let latest_stage: CFStage?
    let created_on: String?

    struct CFTrigger: Decodable {
        let metadata: CFTriggerMetadata?
    }

    struct CFTriggerMetadata: Decodable {
        let commit_message: String?
        let branch: String?
    }

    struct CFStage: Decodable {
        let name: String?
        let status: String?
    }

    func toDeployment(projectName: String) -> Deployment {
        return Deployment(
            id: id,
            providerID: "cloudflare",
            projectName: projectName,
            status: mapStatus(latest_stage?.status),
            url: url.flatMap { URL(string: $0) },
            createdAt: created_on.flatMap { SharedFormatters.iso8601InternetWithFractional.date(from: $0) } ?? Date(),
            commitMessage: deployment_trigger?.metadata?.commit_message,
            branch: deployment_trigger?.metadata?.branch
        )
    }

    private func mapStatus(_ status: String?) -> Deployment.Status {
        switch status?.lowercased() {
        case "success", "active":  return .success
        case "failure":            return .failed
        case "idle":               return .building
        case "canceled":           return .cancelled
        default:                   return .unknown
        }
    }
}
