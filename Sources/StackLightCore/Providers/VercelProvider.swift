import Foundation
import SwiftUI

public final class VercelProvider: DeploymentProvider {
    public let id = "vercel"
    public let displayName = "Vercel"
    public let iconSymbol = "triangleshape.fill"
    public let iconAsset: String? = "vercel"
    public let color = Color.black
    public let docsURL = URL(string: "https://vercel.com/account/tokens")

    /// UserDefaults keys for filter config.
    static let branchFilterKey = "vercel.branchFilter"
    static let hideSkippedKey = "vercel.hideSkippedPreviews"
    static let knownBranchesKey = "vercel.knownBranches"

    /// Sentinel stored in `branchFilterKey` meaning "no filter".
    static let allBranchesSentinel = ""

    public init() {}

    public var dashboardURL: URL? {
        if let teamId = AppConfig.string(forKey: "vercel.teamId"), !teamId.isEmpty {
            return URL(string: "https://vercel.com/\(teamId)")
        }
        return URL(string: "https://vercel.com/dashboard")
    }

    public var isConfigured: Bool {
        guard let token = KeychainManager.read(key: "vercel.token") else { return false }
        return !token.isEmpty
    }

    public func fetchDeployments() async throws -> DeploymentFetchResult {
        guard let token = KeychainManager.read(key: "vercel.token") else { return .empty }

        let projectNames = (AppConfig.string(forKey: "vercel.projectNames") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var components = URLComponents(string: "https://api.vercel.com/v6/deployments")!
        // With a project filter we widen the fetch window so quieter projects
        // don't get drowned out by one noisy project in the first 30 results.
        let limit = projectNames.isEmpty ? 30 : 100
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]

        if let teamId = AppConfig.string(forKey: "vercel.teamId"), !teamId.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "teamId", value: teamId))
        }

        // execute() lets us read service-specific error bodies before throwing;
        // RequestRunner still applies backoff + 429/503 cooldowns.
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, http) = try await RequestRunner.shared.execute(request: request)

        if http.statusCode != 200 {
            if let err = try? SharedJSON.decoder.decode(VercelErrorResponse.self, from: data) {
                throw ProviderError.http(code: http.statusCode, message: err.error.message, body: data)
            }
            throw ProviderError.http(
                code: http.statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode),
                body: data
            )
        }

        let response = try SharedJSON.decoder.decode(VercelResponse.self, from: data)
        let rawDeployments = response.deployments

        // Remember every branch we've seen so the settings picker has real
        // options to offer the next time it opens.
        cacheKnownBranches(from: rawDeployments)

        let branchFilter = (AppConfig.string(forKey: Self.branchFilterKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hideSkipped = AppConfig.bool(forKey: Self.hideSkippedKey)

        let allowedNames = Set(projectNames.map { $0.lowercased() })

        let filtered = rawDeployments
            .filter { deployment in
                guard !allowedNames.isEmpty else { return true }
                return allowedNames.contains(deployment.name.lowercased())
            }
            .filter { deployment in
                if branchFilter.isEmpty { return true }
                guard let ref = deployment.meta?.githubCommitRef, !ref.isEmpty else {
                    return false
                }
                return ref.caseInsensitiveCompare(branchFilter) == .orderedSame
            }
            .filter { deployment in
                guard hideSkipped else { return true }
                return !deployment.isSkippedPreview
            }
            .prefix(10)
            .map { $0.toDeployment() }

        return DeploymentFetchResult(deployments: Array(filtered))
    }

    public func settingsFields() -> [SettingsField] {
        [
            SettingsField(key: "vercel.token", label: "API Token", isSecret: true,
                          placeholder: "Bearer token from Vercel dashboard"),
            SettingsField(key: "vercel.teamId", label: "Team ID",
                          placeholder: "Optional, for team deployments"),
            SettingsField(
                key: Self.branchFilterKey,
                label: "Branch Filter",
                placeholder: "All branches",
                hint: "Only show deployments from the chosen branch.",
                kind: .branchPicker(branchesKey: Self.knownBranchesKey)
            ),
            SettingsField(
                key: Self.hideSkippedKey,
                label: "Hide Skipped Previews",
                hint: "Cancelled preview builds won't appear in the list.",
                kind: .toggle
            ),
            SettingsField(
                key: "vercel.projectNames",
                label: "Project Names",
                placeholder: "my-site, docs-site",
                isMultiValue: true,
                hint: "Leave empty to include all projects under this token."
            )
        ]
    }

    private func cacheKnownBranches(from deployments: [VercelDeployment]) {
        let branches = Set(deployments.compactMap { $0.meta?.githubCommitRef }
            .filter { !$0.isEmpty })
        guard !branches.isEmpty else { return }

        let existing = AppConfig.stringArray(forKey: Self.knownBranchesKey)
        let merged = Array(Set(existing).union(branches)).sorted()
        AppConfig.setValue(merged, forKey: Self.knownBranchesKey)
    }
}

// MARK: - Failure details

extension VercelProvider: FailureDetailsProviding {
    /// Pulls the build log via `GET /v3/deployments/{id}/events`. We fetch
    /// backward (newest first) so a huge log costs one bounded request, then
    /// restore chronological order for display.
    public func fetchFailureDetails(for deployment: Deployment) async throws -> DeploymentFailureDetails {
        guard let token = KeychainManager.read(key: "vercel.token") else {
            throw ProviderError.unauthorized(message: "Vercel token missing")
        }

        var components = URLComponents(string: "https://api.vercel.com/v3/deployments/\(deployment.id)/events")!
        components.queryItems = [
            URLQueryItem(name: "direction", value: "backward"),
            URLQueryItem(name: "limit", value: "200")
        ]
        if let teamId = AppConfig.string(forKey: "vercel.teamId"), !teamId.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "teamId", value: teamId))
        }

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, http) = try await RequestRunner.shared.execute(request: request)

        if http.statusCode != 200 {
            if let err = try? SharedJSON.decoder.decode(VercelErrorResponse.self, from: data) {
                throw ProviderError.http(code: http.statusCode, message: err.error.message, body: data)
            }
            throw ProviderError.http(
                code: http.statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode),
                body: data
            )
        }

        let events = (try? SharedJSON.decoder.decode([VercelBuildEvent].self, from: data)) ?? []
        return Self.failureDetails(fromBackwardEvents: events)
    }

    /// Pure mapping from decoded (newest-first) events to details; separated
    /// out for unit testing.
    static func failureDetails(fromBackwardEvents events: [VercelBuildEvent]) -> DeploymentFailureDetails {
        let logTypes: Set<String> = ["command", "stdout", "stderr", "exit", "fatal"]
        let chronological = events
            .filter { logTypes.contains($0.type ?? "") }
            .reversed()

        var lines: [String] = []
        for event in chronological {
            guard let text = event.logText, !text.isEmpty else { continue }
            let prefix = (event.type == "command") ? "$ " : ""
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append(prefix + String(line))
            }
        }

        guard !lines.isEmpty else {
            return DeploymentFailureDetails(summary: nil)
        }

        let (excerpt, truncated) = DeploymentFailureDetails.tailExcerpt(lines.joined(separator: "\n"))
        // Best-effort headline: the last line that self-identifies as an error.
        let summary = lines.reversed().first { line in
            let lowered = line.lowercased()
            return lowered.contains("error") || lowered.contains("failed") || lowered.contains("fatal")
        }.map { String($0.prefix(200)) }

        return DeploymentFailureDetails(
            summary: summary,
            logExcerpt: excerpt,
            logExcerptTruncated: truncated
        )
    }
}

/// Single build-log event from `/v3/deployments/{id}/events`. Vercel has
/// shipped the text both at the top level and inside `payload` over time, so
/// both are modeled and `logText` picks whichever is present.
struct VercelBuildEvent: Decodable {
    let type: String?
    let created: Double?
    let text: String?
    let payload: Payload?

    struct Payload: Decodable {
        let text: String?
    }

    var logText: String? {
        payload?.text ?? text
    }
}

// MARK: - API Response Models

private struct VercelErrorResponse: Decodable {
    let error: ErrorDetail
    struct ErrorDetail: Decodable {
        let message: String
    }
}

private struct VercelResponse: Decodable {
    let deployments: [VercelDeployment]
}

private struct VercelDeployment: Decodable {
    let uid: String
    let name: String
    let state: String?
    let url: String?
    let created: TimeInterval // milliseconds
    let target: String?
    let meta: VercelMeta?

    struct VercelMeta: Decodable {
        let githubCommitMessage: String?
        let githubCommitRef: String?
    }

    /// A "skipped" preview in Vercel is a non-production deployment that ended
    /// up cancelled — typically because the commit produced no effective
    /// changes or a newer deploy superseded it.
    var isSkippedPreview: Bool {
        let isPreview = (target ?? "").lowercased() != "production"
        return isPreview && (state?.uppercased() == "CANCELED")
    }

    func toDeployment() -> Deployment {
        Deployment(
            id: uid,
            providerID: "vercel",
            projectName: name,
            status: mapStatus(state),
            url: url.flatMap { URL(string: "https://\($0)") },
            createdAt: Date(timeIntervalSince1970: created / 1000),
            commitMessage: meta?.githubCommitMessage,
            branch: meta?.githubCommitRef
        )
    }

    private func mapStatus(_ state: String?) -> Deployment.Status {
        switch state?.uppercased() {
        case "BUILDING":    return .building
        case "READY":       return .success
        case "ERROR":       return .failed
        case "QUEUED":      return .queued
        case "CANCELED":    return .cancelled
        default:            return .unknown
        }
    }
}
