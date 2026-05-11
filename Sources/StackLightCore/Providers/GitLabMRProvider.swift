import Foundation
import SwiftUI

public final class GitLabMRProvider: DeploymentProvider {
    public let id = "gitlabMR"
    public let displayName = "GitLab Merge Requests"
    public let iconSymbol = "arrow.triangle.pull"
    public let iconAsset: String? = "gitlab"
    public let color = Color(red: 0.89, green: 0.30, blue: 0.16)
    public let docsURL = URL(string: "https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html")

    public init() {}

    public var dashboardURL: URL? {
        URL(string: "https://\(GitLabHost.resolved())/dashboard/merge_requests")
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
            try await Self.fetchMergeRequests(host: host, token: token, project: project)
        }
    }

    public func settingsFields() -> [SettingsField] {
        [
            SettingsField(key: "gitlab.host", label: "Host", placeholder: "gitlab.com",
                          hint: "Leave empty for gitlab.com. For self-hosted, enter the bare hostname (e.g. gitlab.acme.com)."),
            SettingsField(key: "gitlab.token", label: "Personal Access Token", isSecret: true, placeholder: "glpat-... (needs read_api scope)"),
            SettingsField(key: "gitlab.mr.projects", label: "Projects", placeholder: "group/project", isMultiValue: true,
                          hint: "Add projects to watch for open MRs")
        ]
    }

    private func configuredProjects() -> [String] {
        (AppConfig.string(forKey: "gitlab.mr.projects") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func fetchMergeRequests(host: String, token: String, project: String) async throws -> [Deployment] {
        let encoded = GitLabHost.encodeProject(project)
        var components = URLComponents(string: "https://\(host)/api/v4/projects/\(encoded)/merge_requests")!
        components.queryItems = [
            URLQueryItem(name: "state", value: "opened"),
            URLQueryItem(name: "order_by", value: "updated_at"),
            URLQueryItem(name: "sort", value: "desc"),
            URLQueryItem(name: "per_page", value: "10")
        ]

        guard let url = components.url else {
            throw GitLabRequestError(statusCode: nil, apiMessage: "Invalid host or project")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, http) = try await RequestRunner.shared.execute(request: request)
        if !(200...299).contains(http.statusCode) {
            let body = try? SharedJSON.decoder.decode(GitLabErrorResponse.self, from: data)
            let message = body?.message ?? body?.error
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw GitLabRequestError(statusCode: http.statusCode, apiMessage: message)
        }
        let mrs = try SharedJSON.iso8601Decoder.decode([GLMergeRequest].self, from: data)
        return mrs.map { $0.toDeployment(project: project) }
    }
}

// MARK: - API Response Models

private struct GLMergeRequest: Decodable {
    let id: Int
    let iid: Int
    let title: String
    let state: String
    let draft: Bool?
    let work_in_progress: Bool?
    let web_url: String?
    let created_at: Date?
    let updated_at: Date?
    let source_branch: String?
    let reviewers: [GLUser]?
    let author: GLUser?

    struct GLUser: Decodable {
        let username: String
    }

    func toDeployment(project: String) -> Deployment {
        Deployment(
            id: "gl-mr-\(project)-\(iid)",
            providerID: "gitlabMR",
            projectName: "\(project)!\(iid)",
            status: mapStatus(),
            url: web_url.flatMap { URL(string: $0) },
            createdAt: updated_at ?? created_at ?? Date(),
            commitMessage: title,
            branch: source_branch
        )
    }

    private func mapStatus() -> Deployment.Status {
        if draft == true || work_in_progress == true {
            return .building
        }
        if let reviewers, !reviewers.isEmpty {
            return .reviewing
        }
        return .queued
    }
}
