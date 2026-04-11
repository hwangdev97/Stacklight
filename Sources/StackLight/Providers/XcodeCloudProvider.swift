import Foundation
import AppStoreConnect_Swift_SDK

final class XcodeCloudProvider: DeploymentProvider {
    let id = "xcodeCloud"
    let displayName = "Xcode Cloud"
    let iconSymbol = "hammer.fill"
    let docsURL = URL(string: "https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api")

    var isConfigured: Bool {
        guard let issuerID = KeychainManager.read(key: "asc.issuerID"),
              let keyID = KeychainManager.read(key: "asc.privateKeyID"),
              let key = KeychainManager.read(key: "asc.privateKey") else {
            return false
        }
        return !issuerID.isEmpty && !keyID.isEmpty && !key.isEmpty
    }

    func fetchDeployments() async throws -> [Deployment] {
        let provider = try makeProvider()

        let productsRequest = APIEndpoint.v1.ciProducts.get(parameters: .init(limit: 25))
        let productsResponse = try await provider.request(productsRequest)

        var deployments: [Deployment] = []
        for product in productsResponse.data {
            let runsRequest = APIEndpoint.v1.ciProducts.id(product.id).buildRuns
                .get(parameters: .init(
                    sort: [.minusnumber],
                    limit: 5
                ))
            let runsResponse = try await provider.request(runsRequest)

            let productName = product.attributes?.name ?? "Build"
            let mapped = runsResponse.data.compactMap { run -> Deployment? in
                guard let attrs = run.attributes else { return nil }
                return Deployment(
                    id: run.id,
                    providerID: "xcodeCloud",
                    projectName: productName,
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
            deployments.append(contentsOf: mapped)
        }
        return deployments
    }

    func settingsFields() -> [SettingsField] {
        [
            SettingsField(key: "asc.issuerID", label: "Issuer ID", isSecret: true, placeholder: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
                          hint: "Users and Access → Integrations → App Store Connect API → Issuer ID (top of page)"),
            SettingsField(key: "asc.privateKeyID", label: "Key ID", isSecret: true, placeholder: "e.g. ABC1234DEF",
                          hint: "Same page → Keys table → Key ID column"),
            SettingsField(key: "asc.privateKey", label: "Private Key (.p8)", isSecret: true, placeholder: "-----BEGIN PRIVATE KEY-----...",
                          hint: "Download the .p8 file when creating the key (one-time only), then paste its contents here")
        ]
    }

    private func makeProvider() throws -> APIProvider {
        guard let issuerID = KeychainManager.read(key: "asc.issuerID"),
              let keyID = KeychainManager.read(key: "asc.privateKeyID"),
              let rawKey = KeychainManager.read(key: "asc.privateKey") else {
            throw NSError(domain: "XcodeCloud", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing API credentials — configure in Settings"])
        }
        // SDK expects raw Base64 key content without PEM header/footer
        let strippedKey = rawKey
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespaces)

        let config = try APIConfiguration(
            issuerID: issuerID,
            privateKeyID: keyID,
            privateKey: strippedKey
        )
        return APIProvider(configuration: config)
    }

    private func mapStatus(
        progress: CiExecutionProgress?,
        completion: CiCompletionStatus?
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
