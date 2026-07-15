import Foundation
import SwiftUI

public final class NetlifyProvider: DeploymentProvider {
    public let id = "netlify"
    public let displayName = "Netlify"
    public let iconSymbol = "network"
    public let iconAsset: String? = "netlify"
    public let color = Color(red: 0.00, green: 0.78, blue: 0.72)
    public let docsURL = URL(string: "https://app.netlify.com/user/applications#personal-access-tokens")

    public let dashboardURL: URL? = URL(string: "https://app.netlify.com")

    public init() {}

    public var isConfigured: Bool {
        guard let token = KeychainManager.read(key: "netlify.token"), !token.isEmpty else { return false }
        let siteIds = AppConfig.string(forKey: "netlify.siteIds") ?? ""
        return !siteIds.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public func fetchDeployments() async throws -> DeploymentFetchResult {
        guard let token = KeychainManager.read(key: "netlify.token") else { return .empty }

        let siteIds = (AppConfig.string(forKey: "netlify.siteIds") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !siteIds.isEmpty else { return .empty }

        return await DeploymentFetchResult.collecting(siteIds, name: { $0 }) { siteId in
            try await Self.fetchDeploys(token: token, siteId: siteId)
        }
    }

    public func settingsFields() -> [SettingsField] {
        [
            SettingsField(key: "netlify.token", label: "Personal Access Token", isSecret: true, placeholder: "PAT from Netlify dashboard"),
            SettingsField(key: "netlify.siteIds", label: "Site IDs", placeholder: "Comma-separated site IDs or names")
        ]
    }

    private static func fetchDeploys(token: String, siteId: String) async throws -> [Deployment] {
        var components = URLComponents(string: "https://api.netlify.com/api/v1/sites/\(siteId)/deploys")!
        components.queryItems = [URLQueryItem(name: "per_page", value: "10")]

        guard let url = components.url else { return [] }
        let (data, _) = try await RequestRunner.shared.get(url: url, token: token)
        let deploys = try SharedJSON.iso8601FractionalDecoder.decode([NetlifyDeploy].self, from: data)
        return deploys.map { $0.toDeployment() }
    }
}

// MARK: - Failure details

extension NetlifyProvider: FailureDetailsProviding {
    /// Netlify surfaces the failure reason directly on the deploy object
    /// (`error_message`), so a single `GET /api/v1/deploys/{id}` suffices.
    /// Full raw logs aren't exposed via the public REST API — the details
    /// link points at the deploy page, which shows them.
    public func fetchFailureDetails(for deployment: Deployment) async throws -> DeploymentFailureDetails {
        guard let token = KeychainManager.read(key: "netlify.token") else {
            throw ProviderError.unauthorized(message: "Netlify token missing")
        }
        // Rows are minted as "netlify-<deployID>".
        let deployID = deployment.id.hasPrefix("netlify-")
            ? String(deployment.id.dropFirst("netlify-".count))
            : deployment.id
        guard let url = URL(string: "https://api.netlify.com/api/v1/deploys/\(deployID)") else {
            return DeploymentFailureDetails()
        }

        let (data, _) = try await RequestRunner.shared.get(url: url, token: token)
        let detail = try SharedJSON.decoder.decode(NetlifyDeployDetail.self, from: data)
        return Self.failureDetails(from: detail, deployID: deployID)
    }

    static func failureDetails(from detail: NetlifyDeployDetail, deployID: String) -> DeploymentFailureDetails {
        let logsURL = detail.admin_url.flatMap { URL(string: "\($0)/deploys/\(deployID)") }
        return DeploymentFailureDetails(
            summary: detail.error_message,
            logsURL: logsURL
        )
    }
}

struct NetlifyDeployDetail: Decodable {
    let id: String?
    let state: String?
    let error_message: String?
    let admin_url: String?
}

// MARK: - API Response Models

private struct NetlifyDeploy: Decodable {
    let id: String
    let site_id: String?
    let state: String?
    let title: String?
    let branch: String?
    let created_at: Date?
    let deploy_url: String?
    let commit_ref: String?
    let context: String?

    func toDeployment() -> Deployment {
        Deployment(
            id: "netlify-\(id)",
            providerID: "netlify",
            projectName: title ?? site_id ?? "Unknown",
            status: mapStatus(state),
            url: deploy_url.flatMap { URL(string: $0) },
            createdAt: created_at ?? Date(),
            commitMessage: nil,
            branch: branch
        )
    }

    private func mapStatus(_ state: String?) -> Deployment.Status {
        switch state {
        case "building", "uploading": return .building
        case "ready", "live":         return .success
        case "failed", "error":       return .failed
        case "queued":                return .queued
        default:                      return .unknown
        }
    }
}

// JSON decoder lives in SharedJSON.iso8601FractionalDecoder.
