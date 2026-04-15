import Foundation

final class NetlifyProvider: DeploymentProvider {
    let id = "netlify"
    let displayName = "Netlify"
    let iconSymbol = "network"
    let docsURL = URL(string: "https://app.netlify.com/user/applications#personal-access-tokens")

    let dashboardURL = URL(string: "https://app.netlify.com")

    var isConfigured: Bool {
        guard let token = KeychainManager.read(key: "netlify.token"), !token.isEmpty else { return false }
        let siteIds = UserDefaults.standard.string(forKey: "netlify.siteIds") ?? ""
        return !siteIds.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func fetchDeployments() async throws -> [Deployment] {
        guard let token = KeychainManager.read(key: "netlify.token") else { return [] }

        let siteIds = (UserDefaults.standard.string(forKey: "netlify.siteIds") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !siteIds.isEmpty else { return [] }

        return try await withThrowingTaskGroup(of: [Deployment].self) { group in
            for siteId in siteIds {
                group.addTask {
                    try await self.fetchDeploys(token: token, siteId: siteId)
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
            SettingsField(key: "netlify.token", label: "Personal Access Token", isSecret: true, placeholder: "PAT from Netlify dashboard"),
            SettingsField(key: "netlify.siteIds", label: "Site IDs", placeholder: "Comma-separated site IDs or names")
        ]
    }

    private func fetchDeploys(token: String, siteId: String) async throws -> [Deployment] {
        var components = URLComponents(string: "https://api.netlify.com/api/v1/sites/\(siteId)/deploys")!
        components.queryItems = [URLQueryItem(name: "per_page", value: "10")]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let deploys = try JSONDecoder.netlifyDecoder.decode([NetlifyDeploy].self, from: data)
        return deploys.map { $0.toDeployment() }
    }
}

// MARK: - API Response Models

private struct NetlifyDeploy: Decodable {
    let id: String
    let site_id: String?
    let state: String?
    let title: String?
    let branch: String?
    let created_at: Date?
    let deploy_url: String?
    let commit_ref: String?
    let context: String?

    func toDeployment() -> Deployment {
        Deployment(
            id: "netlify-\(id)",
            providerID: "netlify",
            projectName: title ?? site_id ?? "Unknown",
            status: mapStatus(state),
            url: deploy_url.flatMap { URL(string: $0) },
            createdAt: created_at ?? Date(),
            commitMessage: nil,
            branch: branch
        )
    }

    private func mapStatus(_ state: String?) -> Deployment.Status {
        switch state {
        case "building", "uploading": return .building
        case "ready", "live":         return .success
        case "failed", "error":       return .failed
        case "queued":                return .queued
        default:                      return .unknown
        }
    }
}

// MARK: - JSON Decoder for Netlify API (ISO8601 dates)

private extension JSONDecoder {
    static let netlifyDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) {
                return date
            }
            // Fallback without fractional seconds
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            if let date = fallback.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(dateString)")
        }
        return decoder
    }()
}
