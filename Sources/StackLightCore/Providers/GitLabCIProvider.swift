import Foundation
import SwiftUI

public final class GitLabCIProvider: DeploymentProvider {
    public let id = "gitlabCI"
    public let displayName = "GitLab CI"
    public let iconSymbol = "diamond.fill"
    public let iconAsset: String? = "gitlab"
    public let color = Color(red: 0.99, green: 0.43, blue: 0.15)
    public let docsURL = URL(string: "https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html")

    public init() {}

    public var dashboardURL: URL? {
        let host = GitLabHost.resolved()
        let projects = configuredProjects()
        if projects.count == 1 {
            return URL(string: "https://\(host)/\(projects[0])/-/pipelines")
        }
        return URL(string: "https://\(host)")
    }

    public var isConfigured: Bool {
        guard let token = KeychainManager.read(key: "gitlab.token"), !token.isEmpty else { return false }
        return !configuredProjects().isEmpty
    }

    public func fetchDeployments() async throws -> DeploymentFetchResult {
        guard let token = KeychainManager.read(key: "gitlab.token") else { return .empty }

        let projects = configuredProjects()
        guard !projects.isEmpty else { return .empty }

        let host = GitLabHost.resolved()
        return await DeploymentFetchResult.collecting(projects, name: { $0 }) { project in
            try await Self.fetchPipelines(host: host, token: token, project: project)
        }
    }

    public func settingsFields() -> [SettingsField] {
        [
            SettingsField(key: "gitlab.host", label: "Host", placeholder: "gitlab.com",
                          hint: "Leave empty for gitlab.com. For self-hosted, enter the bare hostname (e.g. gitlab.acme.com)."),
            SettingsField(key: "gitlab.token", label: "Personal Access Token", isSecret: true, placeholder: "glpat-... (needs read_api scope)"),
            SettingsField(key: "gitlab.projects", label: "Projects", placeholder: "group/project", isMultiValue: true,
                          hint: "Full path. Nested groups OK: group/subgroup/project.")
        ]
    }

    private func configuredProjects() -> [String] {
        (AppConfig.string(forKey: "gitlab.projects") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func fetchPipelines(host: String, token: String, project: String) async throws -> [Deployment] {
        let encoded = GitLabHost.encodeProject(project)
        var components = URLComponents(string: "https://\(host)/api/v4/projects/\(encoded)/pipelines")!
        components.queryItems = [URLQueryItem(name: "per_page", value: "10")]

        guard let url = components.url else {
            throw GitLabRequestError(statusCode: nil, apiMessage: "Invalid host or project")
        }

        let (data, http) = try await RequestRunner.shared.execute(request: {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            return request
        }())
        if !(200...299).contains(http.statusCode) {
            let body = try? SharedJSON.decoder.decode(GitLabErrorResponse.self, from: data)
            let message = body?.message ?? body?.error
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw GitLabRequestError(statusCode: http.statusCode, apiMessage: message)
        }
        let pipelines = try SharedJSON.iso8601Decoder.decode([GLPipeline].self, from: data)
        return pipelines.map { $0.toDeployment(project: project) }
    }
}

// MARK: - Shared helpers

enum GitLabHost {
    /// Normalize the user-entered host into a bare `host[:port]` form.
    /// Falls back to `gitlab.com` when blank.
    static func resolved() -> String {
        let raw = (AppConfig.string(forKey: "gitlab.host") ?? "")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        guard !raw.isEmpty else { return "gitlab.com" }
        var host = raw
        if let scheme = host.range(of: "://") {
            host = String(host[scheme.upperBound...])
        }
        if let slash = host.firstIndex(of: "/") {
            host = String(host[..<slash])
        }
        return host.isEmpty ? "gitlab.com" : host
    }

    /// GitLab requires the project path to be URL-encoded with `/` → `%2F`.
    /// Returns the encoded form ready to drop into the URL path.
    static func encodeProject(_ project: String) -> String {
        // Only `/` matters in practice — other path chars are already safe.
        project.replacingOccurrences(of: "/", with: "%2F")
    }
}

struct GitLabErrorResponse: Decodable {
    // GitLab uses either `message` (most endpoints) or `error` (OAuth-style).
    // `message` is sometimes a plain string and sometimes a nested object; only
    // decode the string variant — anything else falls through to nil.
    let message: String?
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case message, error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        message = try? c.decode(String.self, forKey: .message)
        error = try? c.decode(String.self, forKey: .error)
    }
}

struct GitLabRequestError: LocalizedError {
    let statusCode: Int?
    let apiMessage: String

    var errorDescription: String? {
        switch statusCode {
        case nil:
            return "Use the group/project path format, for example gitlab-org/gitlab."
        case 401:
            return "GitLab token is invalid or expired. Create a new token with read_api scope."
        case 403:
            return "GitLab denied access. Check that the token has read_api scope and can see this project."
        case 404:
            return "Project not found. Check the path and — for self-hosted — that the Host field matches your GitLab instance."
        default:
            return apiMessage.isEmpty ? HTTPURLResponse.localizedString(forStatusCode: statusCode ?? 0) : apiMessage
        }
    }
}

// MARK: - API Response Models

private struct GLPipeline: Decodable {
    let id: Int
    let iid: Int?
    let status: String?
    let ref: String?
    let sha: String?
    let web_url: String?
    let created_at: Date?
    let updated_at: Date?
    let name: String?

    func toDeployment(project: String) -> Deployment {
        let shortProject = project.split(separator: "/").last.map(String.init) ?? project
        return Deployment(
            id: "gl-pipeline-\(project)-\(id)",
            providerID: "gitlabCI",
            projectName: name?.isEmpty == false ? name! : shortProject,
            repository: shortProject,
            status: mapStatus(),
            url: web_url.flatMap { URL(string: $0) },
            createdAt: updated_at ?? created_at ?? Date(),
            commitMessage: sha.map { "\($0.prefix(7))" },
            branch: ref
        )
    }

    private func mapStatus() -> Deployment.Status {
        switch status {
        case "running":                                                                  return .building
        case "success":                                                                  return .success
        case "failed":                                                                   return .failed
        case "canceled", "skipped":                                                      return .cancelled
        case "created", "waiting_for_resource", "preparing", "pending", "scheduled",
             "manual":                                                                   return .queued
        default:                                                                         return .unknown
        }
    }
}
