import Foundation

final class CloudflareProvider: DeploymentProvider {
    let id = "cloudflare"
    let displayName = "Cloudflare Pages"
    let iconSymbol = "cloud.fill"
    let docsURL = URL(string: "https://dash.cloudflare.com/profile/api-tokens")

    var dashboardURL: URL? {
        if let accountId = UserDefaults.standard.string(forKey: "cloudflare.accountId"), !accountId.isEmpty {
            return URL(string: "https://dash.cloudflare.com/\(accountId)/workers-and-pages")
        }
        return URL(string: "https://dash.cloudflare.com")
    }

    var isConfigured: Bool {
        guard let token = KeychainManager.read(key: "cloudflare.token"),
              let accountId = UserDefaults.standard.string(forKey: "cloudflare.accountId") else {
            return false
        }
        return !token.isEmpty && !accountId.isEmpty
    }

    func fetchDeployments() async throws -> [Deployment] {
        guard let token = KeychainManager.read(key: "cloudflare.token"),
              let accountId = UserDefaults.standard.string(forKey: "cloudflare.accountId") else {
            return []
        }

        var projectNames = UserDefaults.standard.string(forKey: "cloudflare.projectNames")?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty } ?? []

        // If no project names specified, auto-discover all Pages projects
        if projectNames.isEmpty {
            projectNames = try await fetchProjectNames(token: token, accountId: accountId)
        }
        guard !projectNames.isEmpty else { return [] }

        var allDeployments: [Deployment] = []
        for projectName in projectNames {
            let deployments = try await fetchProjectDeployments(
                token: token, accountId: accountId, projectName: projectName
            )
            allDeployments.append(contentsOf: deployments)
        }
        return allDeployments
    }

    func settingsFields() -> [SettingsField] {
        [
            SettingsField(key: "cloudflare.token", label: "API Token", isSecret: true, placeholder: "Cloudflare API token"),
            SettingsField(key: "cloudflare.accountId", label: "Account ID", placeholder: "32-character hex string", hint: "Found in your dashboard URL: dash.cloudflare.com/<account-id>"),
            SettingsField(key: "cloudflare.projectNames", label: "Project Names", placeholder: "Comma-separated: my-site, docs",
                          hint: "Leave empty to auto-discover all Pages projects")
        ]
    }

    private func fetchProjectNames(token: String, accountId: String) async throws -> [String] {
        let urlString = "https://api.cloudflare.com/client/v4/accounts/\(accountId)/pages/projects"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(CFProjectsResponse.self, from: data)
        return response.result.map(\.name)
    }

    private func fetchProjectDeployments(token: String, accountId: String, projectName: String) async throws -> [Deployment] {
        let urlString = "https://api.cloudflare.com/client/v4/accounts/\(accountId)/pages/projects/\(projectName)/deployments"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(CFResponse.self, from: data)
        return response.result.prefix(5).map { $0.toDeployment(projectName: projectName) }
    }
}

// MARK: - API Response Models

private struct CFProjectsResponse: Decodable {
    let result: [CFProject]
    struct CFProject: Decodable {
        let name: String
    }
}

private struct CFResponse: Decodable {
    let result: [CFDeployment]
}

private struct CFDeployment: Decodable {
    let id: String
    let url: String?
    let environment: String?
    let deployment_trigger: CFTrigger?
    let latest_stage: CFStage?
    let created_on: String?

    struct CFTrigger: Decodable {
        let metadata: CFTriggerMetadata?
    }

    struct CFTriggerMetadata: Decodable {
        let commit_message: String?
        let branch: String?
    }

    struct CFStage: Decodable {
        let name: String?
        let status: String?
    }

    func toDeployment(projectName: String) -> Deployment {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return Deployment(
            id: id,
            providerID: "cloudflare",
            projectName: projectName,
            status: mapStatus(latest_stage?.status),
            url: url.flatMap { URL(string: $0) },
            createdAt: created_on.flatMap { dateFormatter.date(from: $0) } ?? Date(),
            commitMessage: deployment_trigger?.metadata?.commit_message,
            branch: deployment_trigger?.metadata?.branch
        )
    }

    private func mapStatus(_ status: String?) -> Deployment.Status {
        switch status?.lowercased() {
        case "success", "active":  return .success
        case "failure":            return .failed
        case "idle":               return .building
        case "canceled":           return .cancelled
        default:                   return .unknown
        }
    }
}
