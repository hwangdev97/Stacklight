import Foundation
import SwiftUI

final class GitHubPRProvider: DeploymentProvider {
    let id = "githubPRs"
    let displayName = "GitHub Pull Requests"
    let iconSymbol = "arrow.triangle.pull"
    let iconAsset: String? = "github"
    let color = Color(red: 0.52, green: 0.28, blue: 0.85)
    let docsURL = URL(string: "https://github.com/settings/tokens")

    var dashboardURL: URL? {
        // GitHub's aggregated PR inbox across all repos the user is involved in.
        URL(string: "https://github.com/pulls")
    }

    var isConfigured: Bool {
        guard let token = KeychainManager.read(key: "github.token"), !token.isEmpty else { return false }
        let repos = AppConfig.defaults.string(forKey: "github.pr.repos") ?? ""
        return !repos.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func fetchDeployments() async throws -> DeploymentFetchResult {
        guard let token = KeychainManager.read(key: "github.token") else { return .empty }

        let repos = (AppConfig.defaults.string(forKey: "github.pr.repos") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !repos.isEmpty else { return .empty }

        return await DeploymentFetchResult.collecting(repos, name: { $0 }) { repo in
            try await Self.fetchPullRequests(token: token, repo: repo)
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

    private static func fetchPullRequests(token: String, repo: String) async throws -> [Deployment] {
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

        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        if let http = httpResponse as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let message = (try? JSONDecoder().decode(GitHubErrorResponse.self, from: data))?.message
                ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "GitHubPR", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
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
