import Foundation

final class GitHubActionsProvider: DeploymentProvider {
    let id = "githubActions"
    let displayName = "GitHub Actions"
    let iconSymbol = "gear.badge.checkmark"
    let iconAsset: String? = "github"
    let docsURL = URL(string: "https://github.com/settings/tokens")

    var isConfigured: Bool {
        guard let token = KeychainManager.read(key: "github.token"), !token.isEmpty else { return false }
        let repos = UserDefaults.standard.string(forKey: "github.repos") ?? ""
        return !repos.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func fetchDeployments() async throws -> [Deployment] {
        guard let token = KeychainManager.read(key: "github.token") else { return [] }

        let repos = (UserDefaults.standard.string(forKey: "github.repos") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !repos.isEmpty else { return [] }

        return try await withThrowingTaskGroup(of: [Deployment].self) { group in
            for repo in repos {
                group.addTask {
                    try await self.fetchRuns(token: token, repo: repo)
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
            SettingsField(key: "github.repos", label: "Repositories", placeholder: "owner/repo, owner/repo2")
        ]
    }

    private func fetchRuns(token: String, repo: String) async throws -> [Deployment] {
        var components = URLComponents(string: "https://api.github.com/repos/\(repo)/actions/runs")!
        components.queryItems = [URLQueryItem(name: "per_page", value: "10")]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder.githubDecoder.decode(GHWorkflowRunsResponse.self, from: data)
        return response.workflow_runs.map { $0.toDeployment(repo: repo) }
    }
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
        Deployment(
            id: "gh-\(id)",
            providerID: "githubActions",
            projectName: name ?? repo,
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
