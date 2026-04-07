import Foundation
import AppStoreConnect_Swift_SDK

final class TestFlightProvider: DeploymentProvider {
    let id = "testFlight"
    let displayName = "TestFlight"
    let iconSymbol = "airplane"

    var isConfigured: Bool {
        // Shares credentials with Xcode Cloud
        guard let issuerID = KeychainManager.read(key: "asc.issuerID"),
              let keyID = KeychainManager.read(key: "asc.privateKeyID"),
              let key = KeychainManager.read(key: "asc.privateKey"),
              let appId = UserDefaults.standard.string(forKey: "testflight.appId") else {
            return false
        }
        return !issuerID.isEmpty && !keyID.isEmpty && !key.isEmpty && !appId.isEmpty
    }

    func fetchDeployments() async throws -> [Deployment] {
        guard let provider = makeProvider(),
              let appId = UserDefaults.standard.string(forKey: "testflight.appId") else {
            return []
        }

        let request = APIEndpoint
            .v1
            .builds
            .get(parameters: .init(
                filterApp: [appId],
                sort: [.minusUploadedDate],
                limit: 10
            ))

        let response = try await provider.request(request)
        return response.data.compactMap { build in
            guard let attrs = build.attributes else { return nil }

            let version = attrs.version ?? "?"
            let cfBundleVersion = attrs.cfBundleVersion ?? "?"

            return Deployment(
                id: build.id,
                providerID: "testFlight",
                projectName: "\(version) (\(cfBundleVersion))",
                status: mapStatus(attrs.processingState, betaState: attrs.buildAudienceType),
                url: nil,
                createdAt: attrs.uploadedDate ?? Date(),
                commitMessage: nil,
                branch: nil
            )
        }
    }

    func settingsFields() -> [SettingsField] {
        [
            // ASC credentials are shared with Xcode Cloud - show a note
            SettingsField(key: "testflight.appId", label: "App ID", placeholder: "App Store Connect App ID (numeric)")
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

    private func mapStatus(_ processingState: Build.Attributes.ProcessingState?, betaState: Build.Attributes.BuildAudienceType?) -> Deployment.Status {
        if let processingState {
            switch processingState {
            case .processing:
                return .building
            case .failed:
                return .failed
            case .valid:
                return .success
            case .invalid:
                return .failed
            }
        }
        return .unknown
    }
}
