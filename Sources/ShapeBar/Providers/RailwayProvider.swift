import Foundation

final class RailwayProvider: DeploymentProvider {
    let id = "railway"
    let displayName = "Railway"
    let iconSymbol = "train.side.front.car"
    let docsURL = URL(string: "https://docs.railway.com/reference/public-api#creating-a-token")

    var isConfigured: Bool {
        guard let token = KeychainManager.read(key: "railway.token"), !token.isEmpty else { return false }
        let projectId = UserDefaults.standard.string(forKey: "railway.projectId") ?? ""
        return !projectId.isEmpty
    }

    func fetchDeployments() async throws -> [Deployment] {
        guard let token = KeychainManager.read(key: "railway.token"),
              let projectId = UserDefaults.standard.string(forKey: "railway.projectId"),
              !projectId.isEmpty else {
            return []
        }

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
            return Deployment(
                id: "railway-\(node.id)",
                providerID: "railway",
                projectName: node.meta?.branch ?? "Deploy",
                status: mapStatus(node.status),
                url: node.staticUrl.flatMap { URL(string: "https://\($0)") },
                createdAt: node.createdAt ?? Date(),
                commitMessage: node.meta?.commitMessage,
                branch: node.meta?.branch
            )
        }
    }

    func settingsFields() -> [SettingsField] {
        [
            SettingsField(key: "railway.token", label: "API Token", isSecret: true, placeholder: "Railway API token"),
            SettingsField(key: "railway.projectId", label: "Project ID", placeholder: "Railway project ID")
        ]
    }

    private func mapStatus(_ status: String?) -> Deployment.Status {
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
    }

    struct RailwayMeta: Decodable {
        let commitMessage: String?
        let branch: String?
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
