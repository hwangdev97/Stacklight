import Foundation
import AppStoreConnect_Swift_SDK

final class XcodeCloudProvider: DeploymentProvider {
    let id = "xcodeCloud"
    let displayName = "Xcode Cloud"
    let iconSymbol = "hammer.fill"

    var isConfigured: Bool {
        guard let issuerID = KeychainManager.read(key: "asc.issuerID"),
              let keyID = KeychainManager.read(key: "asc.privateKeyID"),
              let key = KeychainManager.read(key: "asc.privateKey") else {
            return false
        }
        return !issuerID.isEmpty && !keyID.isEmpty && !key.isEmpty
    }

    func fetchDeployments() async throws -> [Deployment] {
        guard let provider = makeProvider() else { return [] }

        let request = APIEndpoint
            .v1
            .ciBuildRuns
            .get(parameters: .init(
                sort: [.minusNumber],
                limit: 10
            ))

        let response = try await provider.request(request)
        return response.data.compactMap { run in
            guard let attrs = run.attributes else { return nil }

            return Deployment(
                id: run.id,
                providerID: "xcodeCloud",
                projectName: attrs.sourceCommit?.commitSha.map { String($0.prefix(7)) } ?? "Build",
                status: mapStatus(
                    progress: attrs.executionProgress,
                    completion: attrs.completionStatus
                ),
                url: nil,
                createdAt: attrs.createdDate ?? Date(),
                commitMessage: attrs.sourceCommit?.message,
                branch: nil
            )
        }
    }

    func settingsFields() -> [SettingsField] {
        [
            SettingsField(key: "asc.issuerID", label: "Issuer ID", isSecret: true, placeholder: "App Store Connect Issuer ID"),
            SettingsField(key: "asc.privateKeyID", label: "Key ID", isSecret: true, placeholder: "Private Key ID"),
            SettingsField(key: "asc.privateKey", label: "Private Key (.p8)", isSecret: true, placeholder: "Paste contents of AuthKey_XXXX.p8")
        ]
    }

    private func makeProvider() -> APIProvider? {
        guard let issuerID = KeychainManager.read(key: "asc.issuerID"),
              let keyID = KeychainManager.read(key: "asc.privateKeyID"),
              let key = KeychainManager.read(key: "asc.privateKey") else {
            return nil
        }
        let config = APIConfiguration(
            issuerID: issuerID,
            privateKeyID: keyID,
            privateKey: key
        )
        return APIProvider(configuration: config)
    }

    private func mapStatus(
        progress: CiBuildRun.Attributes.ExecutionProgress?,
        completion: CiBuildRun.Attributes.CompletionStatus?
    ) -> Deployment.Status {
        if let progress {
            switch progress {
            case .pending: return .queued
            case .running: return .building
            case .complete: break
            }
        }
        if let completion {
            switch completion {
            case .succeeded: return .success
            case .failed, .errored: return .failed
            case .canceled: return .cancelled
            case .skipped: return .cancelled
            }
        }
        return .unknown
    }
}
