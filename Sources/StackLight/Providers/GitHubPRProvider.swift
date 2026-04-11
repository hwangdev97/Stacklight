import Foundation

final class GitHubPRProvider: DeploymentProvider {
    let id = "githubPRs"
    let displayName = "GitHub Pull Requests"
    let iconSymbol = "arrow.triangle.pull"
    let docsURL = URL(string: "https://github.com/settings/tokens")

    var isConfigured: Bool {
        guard let token = KeychainManager.read(key: "github.token"), !token.isEmpty else { return false }
        let repos = UserDefaults.standard.string(forKey: "github.pr.repos") ?? ""
        return !repos.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func fetchDeployments() async throws -> [Deployment] {
        guard let token = KeychainManager.read(key: "github.token") else { return [] }

        let repos = (UserDefaults.standard.string(forKey: "github.pr.repos") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !repos.isEmpty else { return [] }

        return try await withThrowingTaskGroup(of: [Deployment].self) { group in
            for repo in repos {
                group.addTask {
                    try await self.fetchPullRequests(token: token, repo: repo)
                }
            }
            var all: [Deployment] = []
            for try await batch in group {
                all.append(contentsOf: batch)
            }
            return all
        }
    }

    func settingsFields() -> [SettingsField] {
        [
            SettingsField(key: "github.token", label: "Personal Access Token", isSecret: true, placeholder: "ghp_... (needs repo scope)"),
            SettingsField(key: "github.pr.repos", label: "Repositories", placeholder: "owner/repo", isMultiValue: true,
                          hint: "Add repos to watch for open PRs")
        ]
    }

    // MARK: - API

    private func fetchPullRequests(token: String, repo: String) async throws -> [Deployment] {
        var components = URLComponents(string: "https://api.github.com/repos/\(repo)/pulls")!
        components.queryItems = [
            URLQueryItem(name: "state", value: "open"),
            URLQueryItem(name: "per_page", value: "10"),
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "direction", value: "desc")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        let prs = try JSONDecoder.ghPRDecoder.decode([GHPullRequest].self, from: data)
        return prs.map { $0.toDeployment(repo: repo) }
    }
}

// MARK: - API Response Models

private struct GHPullRequest: Decodable {
    let id: Int
    let number: Int
    let title: String
    let state: String
    let draft: Bool
    let html_url: String?
    let created_at: Date?
    let updated_at: Date?
    let user: GHUser?
    let head: GHRef?
    let requested_reviewers: [GHUser]?

    struct GHUser: Decodable {
        let login: String
    }

    struct GHRef: Decodable {
        let ref: String
    }

    func toDeployment(repo: String) -> Deployment {
        Deployment(
            id: "pr-\(repo)-\(number)",
            providerID: "githubPRs",
            projectName: "\(repo)#\(number)",
            status: mapStatus(),
            url: html_url.flatMap { URL(string: $0) },
            createdAt: updated_at ?? created_at ?? Date(),
            commitMessage: title,
            branch: head?.ref
        )
    }

    private func mapStatus() -> Deployment.Status {
        if draft {
            return .building
        }
        if let reviewers = requested_reviewers, !reviewers.isEmpty {
            return .reviewing
        }
        return .queued
    }
}

// MARK: - JSON Decoder for GitHub API (ISO8601 dates)

private extension JSONDecoder {
    static let ghPRDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(dateString)")
        }
        return decoder
    }()
}
