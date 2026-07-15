import Foundation
import SwiftUI

public final class RailwayProvider: DeploymentProvider {
    public let id = "railway"
    public let displayName = "Railway"
    public let iconSymbol = "train.side.front.car"
    public let iconAsset: String? = "railway"
    public let color = Color(red: 0.51, green: 0.47, blue: 0.98)
    public let docsURL = URL(string: "https://docs.railway.com/reference/public-api#creating-a-token")

    public init() {
        AppConfig.migrateSingleToMulti(oldKey: "railway.projectId", newKey: "railway.projectIds")
    }

    public var dashboardURL: URL? {
        let ids = parsedProjectIds()
        if ids.count == 1 {
            return URL(string: "https://railway.com/project/\(ids[0])")
        }
        return URL(string: "https://railway.com/dashboard")
    }

    public var isConfigured: Bool {
        guard let token = KeychainManager.read(key: "railway.token"), !token.isEmpty else { return false }
        return !parsedProjectIds().isEmpty
    }

    public func fetchDeployments() async throws -> DeploymentFetchResult {
        guard let token = KeychainManager.read(key: "railway.token") else { return .empty }

        let projectIds = parsedProjectIds()
        guard !projectIds.isEmpty else { return .empty }

        return await DeploymentFetchResult.collecting(projectIds, name: { $0 }) { projectId in
            try await Self.fetchDeployments(token: token, projectId: projectId)
        }
    }

    public func settingsFields() -> [SettingsField] {
        [
            SettingsField(key: "railway.token", label: "API Token", isSecret: true, placeholder: "Railway API token"),
            SettingsField(key: "railway.projectIds", label: "Project IDs",
                          placeholder: "Railway project IDs",
                          isMultiValue: true,
                          hint: "Add one Railway project ID per entry")
        ]
    }

    // MARK: - Helpers

    private func parsedProjectIds() -> [String] {
        (AppConfig.string(forKey: "railway.projectIds") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func fetchDeployments(token: String, projectId: String) async throws -> [Deployment] {
        let query = """
        query {
          deployments(input: { projectId: "\(projectId)" }, first: 10) {
            edges {
              node {
                id
                status
                createdAt
                staticUrl
                meta {
                  commitMessage
                  branch
                }
                project {
                  name
                }
              }
            }
          }
        }
        """

        let body: [String: Any] = ["query": query]
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "https://backboard.railway.com/graphql/v2")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        // RequestRunner.execute applies backoff + 429/503 cooldowns. We still
        // do our own status check below since GraphQL endpoints often return
        // 200 with `errors` payload rather than HTTP errors.
        let (data, http) = try await RequestRunner.shared.execute(request: request)
        guard http.statusCode == 200 else {
            throw ProviderError.http(
                code: http.statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode),
                body: data
            )
        }
        let response = try SharedJSON.iso8601FractionalDecoder.decode(RailwayGraphQLResponse.self, from: data)

        return (response.data?.deployments?.edges ?? []).compactMap { edge in
            guard let node = edge.node else { return nil }
            let branch = node.meta?.branch
            let projectName = node.project?.name
            let label: String
            switch (projectName, branch) {
            case let (name?, ref?) where !name.isEmpty && !ref.isEmpty:
                label = "\(name) · \(ref)"
            case let (name?, _) where !name.isEmpty:
                label = name
            case let (_, ref?) where !ref.isEmpty:
                label = ref
            default:
                label = "Deploy"
            }
            return Deployment(
                id: "railway-\(node.id)",
                providerID: "railway",
                projectName: label,
                status: mapStatus(node.status),
                url: node.staticUrl.flatMap { URL(string: "https://\($0)") },
                createdAt: node.createdAt ?? Date(),
                commitMessage: node.meta?.commitMessage,
                branch: branch
            )
        }
    }

    private static func mapStatus(_ status: String?) -> Deployment.Status {
        switch status?.uppercased() {
        case "BUILDING", "DEPLOYING": return .building
        case "SUCCESS":               return .success
        case "FAILED", "CRASHED":     return .failed
        case "REMOVED", "SKIPPED":    return .cancelled
        case "QUEUED", "WAITING":     return .queued
        case "SLEEPING":              return .success
        default:                      return .unknown
        }
    }
}

// MARK: - Failure details

extension RailwayProvider: FailureDetailsProviding {
    /// Railway's public GraphQL API exposes `buildLogs` and `deploymentLogs`
    /// per deployment. Build failures live in `buildLogs`; a deploy that
    /// built fine but CRASHED at runtime only has `deploymentLogs`, so we
    /// fall back to those when the build log comes back empty.
    public func fetchFailureDetails(for deployment: Deployment) async throws -> DeploymentFailureDetails {
        guard let token = KeychainManager.read(key: "railway.token") else {
            throw ProviderError.unauthorized(message: "Railway token missing")
        }
        let deploymentID = deployment.id.hasPrefix("railway-")
            ? String(deployment.id.dropFirst("railway-".count))
            : deployment.id

        let buildLogs = try await Self.fetchLogs(field: "buildLogs", token: token, deploymentID: deploymentID)
        var logs = buildLogs
        if logs.isEmpty {
            logs = (try? await Self.fetchLogs(field: "deploymentLogs", token: token, deploymentID: deploymentID)) ?? []
        }
        return Self.failureDetails(from: logs)
    }

    static func failureDetails(from logs: [RailwayLogEntry]) -> DeploymentFailureDetails {
        guard !logs.isEmpty else { return DeploymentFailureDetails() }

        let lines = logs.compactMap { $0.message }
        let (excerpt, truncated) = DeploymentFailureDetails.tailExcerpt(lines.joined(separator: "\n"))

        let errorEntry = logs.reversed().first { entry in
            let severity = entry.severity?.lowercased() ?? ""
            return severity.hasPrefix("err") || severity == "fatal"
        }
        let summary = (errorEntry?.message).map { String($0.prefix(200)) }

        return DeploymentFailureDetails(
            summary: summary,
            logExcerpt: excerpt.isEmpty ? nil : excerpt,
            logExcerptTruncated: truncated
        )
    }

    private static func fetchLogs(
        field: String,
        token: String,
        deploymentID: String
    ) async throws -> [RailwayLogEntry] {
        let query = """
        query {
          \(field)(deploymentId: "\(deploymentID)", limit: 200) {
            timestamp
            message
            severity
          }
        }
        """
        let body: [String: Any] = ["query": query]
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "https://backboard.railway.com/graphql/v2")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, http) = try await RequestRunner.shared.execute(request: request)
        guard http.statusCode == 200 else {
            throw ProviderError.http(
                code: http.statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode),
                body: data
            )
        }
        let response = try SharedJSON.decoder.decode(RailwayLogsResponse.self, from: data)
        if let logs = response.data?.buildLogs ?? response.data?.deploymentLogs {
            return logs
        }
        if let message = response.errors?.first?.message {
            throw ProviderError.http(code: 200, message: message, body: data)
        }
        return []
    }
}

struct RailwayLogEntry: Decodable {
    let timestamp: String?
    let message: String?
    let severity: String?
}

struct RailwayLogsResponse: Decodable {
    let data: LogsData?
    let errors: [GraphQLError]?

    struct LogsData: Decodable {
        let buildLogs: [RailwayLogEntry]?
        let deploymentLogs: [RailwayLogEntry]?
    }

    struct GraphQLError: Decodable {
        let message: String?
    }
}

// MARK: - GraphQL Response Models

private struct RailwayGraphQLResponse: Decodable {
    let data: RailwayData?

    struct RailwayData: Decodable {
        let deployments: RailwayConnection?
    }

    struct RailwayConnection: Decodable {
        let edges: [RailwayEdge]?
    }

    struct RailwayEdge: Decodable {
        let node: RailwayDeployment?
    }

    struct RailwayDeployment: Decodable {
        let id: String
        let status: String?
        let createdAt: Date?
        let staticUrl: String?
        let meta: RailwayMeta?
        let project: RailwayProject?
    }

    struct RailwayMeta: Decodable {
        let commitMessage: String?
        let branch: String?
    }

    struct RailwayProject: Decodable {
        let name: String?
    }
}

// JSON decoder lives in SharedJSON.iso8601FractionalDecoder.
