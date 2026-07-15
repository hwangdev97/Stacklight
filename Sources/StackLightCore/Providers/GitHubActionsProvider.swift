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
        let repos = (AppConfig.string(forKey: "github.repos") ?? "")
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
        let repos = AppConfig.string(forKey: "github.repos") ?? ""
        return !repos.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public func fetchDeployments() async throws -> DeploymentFetchResult {
        guard let token = KeychainManager.read(key: "github.token") else { return .empty }

        let repos = (AppConfig.string(forKey: "github.repos") ?? "")
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

        let (data, http) = try await RequestRunner.shared.execute(request: {
            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            return request
        }())
        if !(200...299).contains(http.statusCode) {
            let message = (try? SharedJSON.decoder.decode(GitHubErrorResponse.self, from: data))?.message
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw ProviderError.http(code: http.statusCode, message: message, body: data)
        }
        let response = try SharedJSON.iso8601Decoder.decode(GHWorkflowRunsResponse.self, from: data)
        return response.workflow_runs.map { $0.toDeployment(repo: repo) }
    }
}

struct GitHubErrorResponse: Decodable {
    let message: String
}

// MARK: - Failure details

extension GitHubActionsProvider: FailureDetailsProviding {
    /// Failure details for a workflow run: the run's failed jobs/steps, plus
    /// the check-run annotations GitHub extracts from the log (`::error::`
    /// lines, compiler diagnostics). Two-step fetch:
    ///   1. `GET /repos/{owner}/{repo}/actions/runs/{id}/jobs`
    ///   2. per failed job, `GET /repos/{owner}/{repo}/check-runs/{jobID}/annotations`
    /// (an Actions job ID doubles as its check-run ID).
    public func fetchFailureDetails(for deployment: Deployment) async throws -> DeploymentFailureDetails {
        guard let token = KeychainManager.read(key: "github.token") else {
            throw ProviderError.unauthorized(message: "GitHub token missing")
        }
        guard let (ownerRepo, runID) = Self.runCoordinates(for: deployment) else {
            // Can't map the row back to a run — return empty details so the
            // UI falls back to metadata-only rather than surfacing an error.
            return DeploymentFailureDetails()
        }

        let headers = [
            "Authorization": "Bearer \(token)",
            "Accept": "application/vnd.github+json"
        ]

        var components = URLComponents(string: "https://api.github.com/repos/\(ownerRepo)/actions/runs/\(runID)/jobs")!
        components.queryItems = [
            URLQueryItem(name: "filter", value: "latest"),
            URLQueryItem(name: "per_page", value: "50")
        ]
        let (jobsData, _) = try await RequestRunner.shared.get(
            url: components.url!, headers: headers
        )
        let jobsResponse = try SharedJSON.decoder.decode(GHJobsResponse.self, from: jobsData)

        // Annotations are best-effort: a 403/410 on one check run shouldn't
        // sink the whole card, so failures collapse to "no annotations".
        var annotationsByJob: [Int: [GHAnnotation]] = [:]
        for job in jobsResponse.jobs.filter({ $0.isFailed }).prefix(3) {
            let url = URL(string: "https://api.github.com/repos/\(ownerRepo)/check-runs/\(job.id)/annotations?per_page=50")!
            if let (data, _) = try? await RequestRunner.shared.get(url: url, headers: headers),
               let annotations = try? SharedJSON.decoder.decode([GHAnnotation].self, from: data) {
                annotationsByJob[job.id] = annotations
            }
        }

        return Self.failureDetails(jobs: jobsResponse.jobs, annotationsByJob: annotationsByJob)
    }

    /// `("owner/repo", runID)` recovered from the deployment row. The row's
    /// URL (`https://github.com/{owner}/{repo}/actions/runs/{id}`) is
    /// authoritative; the `gh-` id prefix is only a consistency check.
    static func runCoordinates(for deployment: Deployment) -> (ownerRepo: String, runID: String)? {
        guard let url = deployment.url else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        // ["owner", "repo", "actions", "runs", "12345"]
        guard parts.count >= 5, parts[2] == "actions", parts[3] == "runs" else { return nil }
        return ("\(parts[0])/\(parts[1])", parts[4])
    }

    static func failureDetails(
        jobs: [GHJob],
        annotationsByJob: [Int: [GHAnnotation]]
    ) -> DeploymentFailureDetails {
        let failedJobs = jobs.filter { $0.isFailed }
        guard !failedJobs.isEmpty else {
            return DeploymentFailureDetails()
        }

        let summary: String
        if failedJobs.count == 1, let job = failedJobs.first {
            if let step = job.firstFailedStepName {
                summary = "Job “\(job.name)” failed at step “\(step)”"
            } else {
                summary = "Job “\(job.name)” failed"
            }
        } else {
            summary = "\(failedJobs.count) of \(jobs.count) jobs failed"
        }

        var issues: [DeploymentFailureDetails.Issue] = []
        for job in failedJobs.prefix(3) {
            if failedJobs.count > 1 {
                issues.append(.init(
                    severity: .error,
                    message: "Job “\(job.name)” failed" + (job.firstFailedStepName.map { " at step “\($0)”" } ?? ""),
                    source: job.name
                ))
            }
            for annotation in (annotationsByJob[job.id] ?? []).filter({ $0.isRelevant }).prefix(6) {
                guard let message = annotation.message, !message.isEmpty else { continue }
                issues.append(.init(
                    severity: annotation.severity,
                    message: String(message.prefix(500)),
                    source: annotation.location(jobName: job.name)
                ))
            }
        }

        return DeploymentFailureDetails(
            summary: summary,
            issues: Array(issues.prefix(8)),
            logsURL: failedJobs.first?.html_url.flatMap { URL(string: $0) }
        )
    }
}

struct GHJobsResponse: Decodable {
    let jobs: [GHJob]
}

struct GHJob: Decodable {
    let id: Int
    let name: String
    let status: String?
    let conclusion: String?
    let html_url: String?
    let steps: [GHJobStep]?

    struct GHJobStep: Decodable {
        let name: String
        let conclusion: String?
    }

    var isFailed: Bool {
        conclusion == "failure" || conclusion == "timed_out"
    }

    var firstFailedStepName: String? {
        steps?.first { $0.conclusion == "failure" || $0.conclusion == "timed_out" }?.name
    }
}

struct GHAnnotation: Decodable {
    let path: String?
    let start_line: Int?
    let annotation_level: String?
    let title: String?
    let message: String?

    /// Skip pure-noise notices ("Node 16 is deprecated"-style warnings stay,
    /// notices only survive when nothing better exists — filtered by caller
    /// keeping errors/warnings).
    var isRelevant: Bool {
        annotation_level == "failure" || annotation_level == "warning"
    }

    var severity: DeploymentFailureDetails.Issue.Severity {
        switch annotation_level {
        case "failure": return .error
        case "warning": return .warning
        default:        return .note
        }
    }

    func location(jobName: String) -> String {
        if let path, !path.isEmpty, path != ".github" {
            if let line = start_line, line > 0 {
                return "\(path):\(line)"
            }
            return path
        }
        return jobName
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

// JSON decoder for GitHub APIs lives in SharedJSON.iso8601Decoder.
