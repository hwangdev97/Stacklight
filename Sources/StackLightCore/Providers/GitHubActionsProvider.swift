import Foundation
import SwiftUI

public final class GitHubActionsProvider: DeploymentProvider {
    public let id = "githubActions"
    public let displayName = "GitHub Actions"
    public let iconSymbol = "gear.badge.checkmark"
    public let iconAsset: String? = "github"
    public let color = Color(red: 0.14, green: 0.16, blue: 0.19)
    public let docsURL = URL(string: "https://github.com/settings/tokens")

    public init() {}

    public var dashboardURL: URL? {
        // If a single repo is configured, jump straight to its Actions tab;
        // otherwise open the user's global "recent activity" feed.
        let repos = (AppConfig.defaults.string(forKey: "github.repos") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if repos.count == 1 {
            return URL(string: "https://github.com/\(repos[0])/actions")
        }
        return URL(string: "https://github.com")
    }

    public var isConfigured: Bool {
        guard let token = KeychainManager.read(key: "github.token"), !token.isEmpty else { return false }
        let repos = AppConfig.defaults.string(forKey: "github.repos") ?? ""
        return !repos.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public func fetchDeployments() async throws -> DeploymentFetchResult {
        guard let token = KeychainManager.read(key: "github.token") else { return .empty }

        let repos = (AppConfig.defaults.string(forKey: "github.repos") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !repos.isEmpty else { return .empty }

        return await DeploymentFetchResult.collecting(repos, name: { $0 }) { repo in
            try await Self.fetchRuns(token: token, repo: repo)
        }
    }

    public func settingsFields() -> [SettingsField] {
        [
            SettingsField(key: "github.token", label: "Personal Access Token", isSecret: true, placeholder: "ghp_... (needs repo scope)"),
            SettingsField(key: "github.repos", label: "Repositories", placeholder: "owner/repo", isMultiValue: true,
                          hint: "Add repos to watch for workflow runs")
        ]
    }

    private static func fetchRuns(token: String, repo: String) async throws -> [Deployment] {
        var components = URLComponents(string: "https://api.github.com/repos/\(repo)/actions/runs")!
        components.queryItems = [URLQueryItem(name: "per_page", value: "10")]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        if let http = httpResponse as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let message = (try? JSONDecoder().decode(GitHubErrorResponse.self, from: data))?.message
                ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "GitHubActions", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
        let response = try JSONDecoder.githubDecoder.decode(GHWorkflowRunsResponse.self, from: data)
        return response.workflow_runs.map { $0.toDeployment(repo: repo) }
    }
}

struct GitHubErrorResponse: Decodable {
    let message: String
}

// MARK: - API Response Models

private struct GHWorkflowRunsResponse: Decodable {
    let workflow_runs: [GHWorkflowRun]
}

private struct GHWorkflowRun: Decodable {
    let id: Int
    let name: String?
    let status: String?
    let conclusion: String?
    let head_branch: String?
    let html_url: String?
    let created_at: Date?
    let head_commit: GHHeadCommit?

    struct GHHeadCommit: Decodable {
        let message: String?
    }

    func toDeployment(repo: String) -> Deployment {
        // Show just the repo name (after the slash) so the row stays compact;
        // fall back to the full identifier if there's no owner prefix.
        let shortRepo = repo.split(separator: "/").last.map(String.init) ?? repo
        return Deployment(
            id: "gh-\(id)",
            providerID: "githubActions",
            projectName: name ?? shortRepo,
            repository: shortRepo,
            status: mapStatus(),
            url: html_url.flatMap { URL(string: $0) },
            createdAt: created_at ?? Date(),
            commitMessage: head_commit?.message,
            branch: head_branch
        )
    }

    private func mapStatus() -> Deployment.Status {
        switch status {
        case "queued":      return .queued
        case "in_progress": return .building
        case "completed":
            switch conclusion {
            case "success":   return .success
            case "failure":   return .failed
            case "cancelled": return .cancelled
            case "skipped":   return .cancelled
            case "timed_out": return .failed
            default:          return .unknown
            }
        default: return .unknown
        }
    }
}

// MARK: - JSON Decoder for GitHub API (ISO8601 dates)

private extension JSONDecoder {
    static let githubDecoder: JSONDecoder = {
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
