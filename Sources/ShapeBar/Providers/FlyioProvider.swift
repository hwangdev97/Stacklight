import Foundation

final class FlyioProvider: DeploymentProvider {
    let id = "flyio"
    let displayName = "Fly.io"
    let iconSymbol = "paperplane.fill"
    let docsURL = URL(string: "https://fly.io/docs/flyctl/tokens-create/")

    var isConfigured: Bool {
        guard let token = KeychainManager.read(key: "flyio.token"), !token.isEmpty else { return false }
        let apps = UserDefaults.standard.string(forKey: "flyio.apps") ?? ""
        return !apps.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func fetchDeployments() async throws -> [Deployment] {
        guard let token = KeychainManager.read(key: "flyio.token") else { return [] }

        let apps = (UserDefaults.standard.string(forKey: "flyio.apps") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !apps.isEmpty else { return [] }

        return try await withThrowingTaskGroup(of: [Deployment].self) { group in
            for app in apps {
                group.addTask {
                    try await self.fetchMachines(token: token, app: app)
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
            SettingsField(key: "flyio.token", label: "API Token", isSecret: true, placeholder: "Fly.io API token (fly tokens create)"),
            SettingsField(key: "flyio.apps", label: "App Names", placeholder: "Comma-separated: my-app, my-api")
        ]
    }

    private func fetchMachines(token: String, app: String) async throws -> [Deployment] {
        guard let url = URL(string: "https://api.machines.dev/v1/apps/\(app)/machines") else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let machines = try JSONDecoder.flyDecoder.decode([FlyMachine].self, from: data)

        return machines.map { machine in
            Deployment(
                id: "fly-\(machine.id)",
                providerID: "flyio",
                projectName: "\(app)/\(machine.name ?? machine.id)",
                status: mapStatus(machine.state),
                url: URL(string: "https://fly.io/apps/\(app)/machines/\(machine.id)"),
                createdAt: machine.created_at ?? Date(),
                commitMessage: machine.image_ref?.labels?.version,
                branch: machine.region
            )
        }
    }

    private func mapStatus(_ state: String?) -> Deployment.Status {
        switch state {
        case "started":                              return .success
        case "stopped", "suspended":                 return .cancelled
        case "created", "creating", "starting",
             "restarting", "updating", "replacing":  return .building
        case "failed", "launch_failed":              return .failed
        case "destroyed", "replaced", "migrated":    return .cancelled
        default:                                     return .unknown
        }
    }
}

// MARK: - API Response Models

private struct FlyMachine: Decodable {
    let id: String
    let name: String?
    let state: String?
    let region: String?
    let created_at: Date?
    let updated_at: Date?
    let image_ref: FlyImageRef?

    struct FlyImageRef: Decodable {
        let repository: String?
        let tag: String?
        let labels: FlyLabels?
    }

    struct FlyLabels: Decodable {
        let version: String?
    }
}

private extension JSONDecoder {
    static let flyDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) { return date }
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            if let date = fallback.date(from: dateString) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(dateString)")
        }
        return decoder
    }()
}
