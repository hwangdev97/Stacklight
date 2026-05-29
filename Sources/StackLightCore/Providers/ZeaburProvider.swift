import Foundation
import SwiftUI

public final class ZeaburProvider: DeploymentProvider {
    public let id = "zeabur"
    public let displayName = "Zeabur"
    public let iconSymbol = "bolt.horizontal.fill"
    public let iconAsset: String? = "zeabur"
    public let color = Color(red: 0.39, green: 0.00, blue: 1.00)
    public let docsURL = URL(string: "https://zeabur.com/docs/en-US/developer/api-keys")

    public var dashboardURL: URL? {
        let ids = parsedProjectIds()
        if ids.count == 1 {
            return URL(string: "https://zeabur.com/projects/\(ids[0])")
        }
        return URL(string: "https://zeabur.com/projects")
    }

    public init() {}

    public var isConfigured: Bool {
        guard let token = KeychainManager.read(key: "zeabur.token"), !token.isEmpty else { return false }
        return true
    }

    public func fetchDeployments() async throws -> DeploymentFetchResult {
        guard let token = KeychainManager.read(key: "zeabur.token") else { return .empty }

        let projectIds = parsedProjectIds()
        let ownerId = parsedOwnerId()

        if projectIds.isEmpty {
            let projects = try await Self.fetchProjects(token: token, ownerId: ownerId)
            return await Self.collectDeployments(token: token, projects: projects, itemErrors: [])
        } else {
            let projectResult = await Self.collectProjects(token: token, projectIds: projectIds)
            return await Self.collectDeployments(
                token: token,
                projects: projectResult.projects,
                itemErrors: projectResult.itemErrors
            )
        }
    }

    public func settingsFields() -> [SettingsField] {
        [
            SettingsField(key: "zeabur.token", label: "API Key", isSecret: true, placeholder: "Zeabur API key"),
            SettingsField(key: "zeabur.ownerId", label: "Owner / Team ID",
                          placeholder: "Optional team owner ID",
                          hint: "Leave empty for personal projects. For team projects, paste the team ID used as ownerID in Zeabur's API."),
            SettingsField(key: "zeabur.projectIds", label: "Project IDs",
                          placeholder: "Optional Zeabur project IDs",
                          isMultiValue: true,
                          hint: "Leave empty to include all projects for this owner. Add IDs to monitor only selected projects.")
        ]
    }

    // MARK: - Helpers

    private func parsedProjectIds() -> [String] {
        (AppConfig.string(forKey: "zeabur.projectIds") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func parsedOwnerId() -> String? {
        let raw = (AppConfig.string(forKey: "zeabur.ownerId") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? nil : raw
    }

    private static func collectDeployments(
        token: String,
        projects: [ZeaburProject],
        itemErrors: [(item: String, error: Error)]
    ) async -> DeploymentFetchResult {
        let targets = projects.flatMap { project in
            project.services.flatMap { service in
                project.environments.map { environment in
                    ZeaburDeploymentTarget(project: project, service: service, environment: environment)
                }
            }
        }

        let result = await DeploymentFetchResult.collecting(targets, name: \.displayName) { target in
            try await fetchDeployments(token: token, target: target)
        }

        return DeploymentFetchResult(
            deployments: result.deployments.sorted { $0.createdAt > $1.createdAt },
            itemErrors: itemErrors + result.itemErrors
        )
    }

    private static func collectProjects(
        token: String,
        projectIds: [String]
    ) async -> (projects: [ZeaburProject], itemErrors: [(item: String, error: Error)]) {
        await withTaskGroup(of: (String, Result<ZeaburProject, Error>).self) { group in
            for projectId in projectIds {
                group.addTask {
                    do {
                        return (projectId, .success(try await fetchProject(token: token, projectId: projectId)))
                    } catch {
                        return (projectId, .failure(error))
                    }
                }
            }

            var projects: [ZeaburProject] = []
            var itemErrors: [(item: String, error: Error)] = []
            for await (projectId, result) in group {
                switch result {
                case .success(let project):
                    projects.append(project)
                case .failure(let error):
                    itemErrors.append((item: projectId, error: error))
                }
            }
            return (projects, itemErrors)
        }
    }

    private static func fetchProjects(token: String, ownerId: String?) async throws -> [ZeaburProject] {
        var variables: [String: Any] = [:]
        if let ownerId {
            variables["ownerID"] = ownerId
        }

        let response = try await graphQL(
            token: token,
            query: """
            query Projects($ownerID: ObjectID) {
              projects(ownerID: $ownerID) {
                edges {
                  node {
                    _id
                    name
                    services {
                      _id
                      name
                    }
                    environments {
                      _id
                      name
                    }
                  }
                }
              }
            }
            """,
            variables: variables,
            as: ZeaburProjectsResponse.self
        )

        return (response.data?.projects?.edges ?? []).compactMap(\.node)
    }

    private static func fetchProject(token: String, projectId: String) async throws -> ZeaburProject {
        let response = try await graphQL(
            token: token,
            query: """
            query Project($projectID: ObjectID!) {
              project(_id: $projectID) {
                _id
                name
                services {
                  _id
                  name
                }
                environments {
                  _id
                  name
                }
              }
            }
            """,
            variables: ["projectID": projectId],
            as: ZeaburProjectResponse.self
        )

        guard let project = response.data?.project else {
            throw ProviderError.invalidResponse
        }
        return project
    }

    private static func fetchDeployments(
        token: String,
        target: ZeaburDeploymentTarget
    ) async throws -> [Deployment] {
        let response = try await graphQL(
            token: token,
            query: """
            query Deployments($serviceID: ObjectID!, $environmentID: ObjectID!) {
              deployments(serviceID: $serviceID, environmentID: $environmentID) {
                edges {
                  node {
                    _id
                    status
                    createdAt
                    startedAt
                    finishedAt
                    commitMessage
                    commitSHA
                  }
                }
              }
            }
            """,
            variables: [
                "serviceID": target.service.id,
                "environmentID": target.environment.id
            ],
            as: ZeaburDeploymentsResponse.self
        )

        return (response.data?.deployments?.edges ?? [])
            .prefix(10)
            .compactMap(\.node)
            .map { deployment in
                Deployment(
                    id: "zeabur-\(deployment.id)-\(target.environment.id)",
                    providerID: "zeabur",
                    projectName: target.displayName,
                    status: mapStatus(deployment.status),
                    url: URL(string: "https://zeabur.com/projects/\(target.project.id)/services/\(target.service.id)"),
                    createdAt: deployment.createdAt ?? deployment.startedAt ?? deployment.finishedAt ?? Date(),
                    commitMessage: deployment.commitMessage ?? deployment.commitSHA,
                    branch: target.environment.name
                )
            }
    }

    private static func graphQL<Response: Decodable>(
        token: String,
        query: String,
        variables: [String: Any],
        as responseType: Response.Type
    ) async throws -> Response {
        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "https://api.zeabur.com/graphql")!)
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

        let response = try SharedJSON.iso8601FractionalDecoder.decode(responseType, from: data)
        if let envelope = response as? ZeaburGraphQLErrorEnvelope,
           let error = envelope.graphQLError {
            throw mapGraphQLError(error, body: data)
        }
        return response
    }

    private static func mapGraphQLError(_ error: ZeaburGraphQLError, body: Data) -> ProviderError {
        let message = error.message
        let normalized = message.lowercased()
        if normalized.contains("unauthorized") || normalized.contains("please login") {
            return .unauthorized(message: message)
        }

        switch error.extensions?.code {
        case "NOT_FOUND", "SERVICE_NOT_FOUND":
            return .http(code: 404, message: message, body: body)
        case "GRAPHQL_VALIDATION_FAILED":
            return .http(code: 400, message: message, body: body)
        default:
            return .http(code: 400, message: message, body: body)
        }
    }

    private static func mapStatus(_ status: String?) -> Deployment.Status {
        switch status?.uppercased() {
        case "BUILDING", "DEPLOYING", "INSTALLING", "STARTING", "UPDATING":
            return .building
        case "READY", "SUCCEEDED", "SUCCESS", "FINISHED", "COMPLETED", "ACTIVE":
            return .success
        case "FAILED", "FAILURE", "CRASHED", "ERROR":
            return .failed
        case "CANCELLED", "CANCELED", "ABORTED", "REMOVED":
            return .cancelled
        case "QUEUED", "PENDING", "WAITING":
            return .queued
        default:
            return .unknown
        }
    }
}

// MARK: - GraphQL Response Models

private protocol ZeaburGraphQLErrorEnvelope {
    var graphQLError: ZeaburGraphQLError? { get }
}

private struct ZeaburGraphQLResponse<DataPayload: Decodable>: Decodable, ZeaburGraphQLErrorEnvelope {
    let data: DataPayload?
    let errors: [ZeaburGraphQLError]?

    var graphQLError: ZeaburGraphQLError? {
        errors?.first
    }
}

private typealias ZeaburProjectResponse = ZeaburGraphQLResponse<ZeaburProjectData>
private typealias ZeaburProjectsResponse = ZeaburGraphQLResponse<ZeaburProjectsData>
private typealias ZeaburDeploymentsResponse = ZeaburGraphQLResponse<ZeaburDeploymentsData>

private struct ZeaburGraphQLError: Decodable {
    let message: String
    let extensions: Extensions?

    struct Extensions: Decodable {
        let code: String?
    }
}

private struct ZeaburProjectData: Decodable {
    let project: ZeaburProject?
}

private struct ZeaburProjectsData: Decodable {
    let projects: ZeaburProjectConnection?
}

private struct ZeaburProjectConnection: Decodable {
    let edges: [ZeaburProjectEdge]
}

private struct ZeaburProjectEdge: Decodable {
    let node: ZeaburProject?
}

private struct ZeaburProject: Decodable, Sendable {
    let id: String
    let name: String
    let services: [ZeaburService]
    let environments: [ZeaburEnvironment]

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case services
        case environments
    }
}

private struct ZeaburService: Decodable, Sendable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
    }
}

private struct ZeaburEnvironment: Decodable, Sendable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
    }
}

private struct ZeaburDeploymentTarget: Sendable {
    let project: ZeaburProject
    let service: ZeaburService
    let environment: ZeaburEnvironment

    var displayName: String {
        "\(project.name) · \(service.name) · \(environment.name)"
    }
}

private struct ZeaburDeploymentsData: Decodable {
    let deployments: ZeaburDeploymentConnection?
}

private struct ZeaburDeploymentConnection: Decodable {
    let edges: [ZeaburDeploymentEdge]
}

private struct ZeaburDeploymentEdge: Decodable {
    let node: ZeaburDeployment?
}

private struct ZeaburDeployment: Decodable {
    let id: String
    let status: String?
    let createdAt: Date?
    let startedAt: Date?
    let finishedAt: Date?
    let commitMessage: String?
    let commitSHA: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case status
        case createdAt
        case startedAt
        case finishedAt
        case commitMessage
        case commitSHA
    }
}
