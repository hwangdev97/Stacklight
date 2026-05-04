import Foundation
import SwiftUI
import AppStoreConnect_Swift_SDK

public final class XcodeCloudProvider: DeploymentProvider {
    public let id = "xcodeCloud"
    public let displayName = "Xcode Cloud"
    public let iconSymbol = "hammer.fill"
    public let iconAsset: String? = "xcode"
    public let color = Color(red: 0.10, green: 0.46, blue: 0.98)
    public let docsURL = URL(string: "https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api")

    // App Store Connect doesn't have a stable per-team dashboard URL without
    // the team ID; land on the apps list which is where Xcode Cloud lives.
    public let dashboardURL: URL? = URL(string: "https://appstoreconnect.apple.com/apps")

    public init() {}

    public var isConfigured: Bool {
        ASCCredentialStore.current() != nil
    }

    public func fetchDeployments() async throws -> DeploymentFetchResult {
        let provider = try makeProvider()

        let productsRequest = APIEndpoint.v1.ciProducts.get(parameters: .init(limit: 25))
        let productsResponse = try await provider.request(productsRequest)

        var deployments: [Deployment] = []
        var itemErrors: [(item: String, error: Error)] = []
        for product in productsResponse.data {
            let productName = product.attributes?.name ?? "Build"
            do {
                let runsRequest = APIEndpoint.v1.ciProducts.id(product.id).buildRuns
                    .get(parameters: .init(
                        sort: [.minusnumber],
                        limit: 5
                    ))
                let runsResponse = try await provider.request(runsRequest)

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
            } catch {
                itemErrors.append((item: productName, error: error))
            }
        }
        return DeploymentFetchResult(deployments: deployments, itemErrors: itemErrors)
    }

    public func settingsFields() -> [SettingsField] {
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
        guard let credentials = ASCCredentialStore.current() else {
            throw NSError(domain: "XcodeCloud", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing API credentials — configure in Settings"])
        }
        let config = try APIConfiguration(
            issuerID: credentials.issuerID,
            privateKeyID: credentials.keyID,
            privateKey: credentials.privateKey
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
