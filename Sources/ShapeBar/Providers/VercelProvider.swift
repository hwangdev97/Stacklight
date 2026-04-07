import Foundation

final class VercelProvider: DeploymentProvider {
    let id = "vercel"
    let displayName = "Vercel"
    let iconSymbol = "globe"

    var isConfigured: Bool {
        guard let token = KeychainManager.read(key: "vercel.token") else { return false }
        return !token.isEmpty
    }

    func fetchDeployments() async throws -> [Deployment] {
        guard let token = KeychainManager.read(key: "vercel.token") else { return [] }

        var components = URLComponents(string: "https://api.vercel.com/v6/deployments")!
        components.queryItems = [URLQueryItem(name: "limit", value: "10")]

        if let teamId = UserDefaults.standard.string(forKey: "vercel.teamId"), !teamId.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "teamId", value: teamId))
        }

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(VercelResponse.self, from: data)
        return response.deployments.map { $0.toDeployment() }
    }

    func settingsFields() -> [SettingsField] {
        [
            SettingsField(key: "vercel.token", label: "API Token", isSecret: true, placeholder: "Bearer token from Vercel dashboard"),
            SettingsField(key: "vercel.teamId", label: "Team ID", placeholder: "Optional, for team deployments")
        ]
    }
}

// MARK: - API Response Models

private struct VercelResponse: Decodable {
    let deployments: [VercelDeployment]
}

private struct VercelDeployment: Decodable {
    let uid: String
    let name: String
    let state: String?
    let url: String?
    let created: TimeInterval // milliseconds
    let meta: VercelMeta?

    struct VercelMeta: Decodable {
        let githubCommitMessage: String?
        let githubCommitRef: String?
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
