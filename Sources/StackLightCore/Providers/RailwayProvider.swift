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
        (AppConfig.defaults.string(forKey: "railway.projectIds") ?? "")
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

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder.railwayDecoder.decode(RailwayGraphQLResponse.self, from: data)

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

private extension JSONDecoder {
    static let railwayDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) { return date }
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            if let date = fallback.date(from: dateString) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(dateString)")
        }
        return decoder
    }()
}
