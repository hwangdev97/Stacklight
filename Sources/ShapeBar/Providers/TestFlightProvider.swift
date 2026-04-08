import Foundation
import AppStoreConnect_Swift_SDK

final class TestFlightProvider: DeploymentProvider {
    let id = "testFlight"
    let displayName = "TestFlight"
    let iconSymbol = "airplane"
    let docsURL = URL(string: "https://appstoreconnect.apple.com/apps")

    var isConfigured: Bool {
        guard let issuerID = KeychainManager.read(key: "asc.issuerID"),
              let keyID = KeychainManager.read(key: "asc.privateKeyID"),
              let key = KeychainManager.read(key: "asc.privateKey"),
              let appId = UserDefaults.standard.string(forKey: "testflight.appId") else {
            return false
        }
        return !issuerID.isEmpty && !keyID.isEmpty && !key.isEmpty && !appId.isEmpty
    }

    func fetchDeployments() async throws -> [Deployment] {
        guard let appId = UserDefaults.standard.string(forKey: "testflight.appId"), !appId.isEmpty else {
            return []
        }

        let provider = try makeProvider()

        let request = APIEndpoint
            .v1
            .builds
            .get(parameters: .init(
                filterApp: [appId],
                sort: [.minusuploadedDate],
                limit: 10
            ))

        let response = try await provider.request(request)
        return response.data.compactMap { build in
            guard let attrs = build.attributes else { return nil }

            let version = attrs.version ?? "?"

            return Deployment(
                id: build.id,
                providerID: "testFlight",
                projectName: "v\(version)",
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
            SettingsField(key: "testflight.appId", label: "App ID", placeholder: "App Store Connect App ID (numeric)",
                          hint: "API credentials are shared with Xcode Cloud — configure them in the Xcode Cloud tab first")
        ]
    }

    private func makeProvider() throws -> APIProvider {
        guard let issuerID = KeychainManager.read(key: "asc.issuerID"),
              let keyID = KeychainManager.read(key: "asc.privateKeyID"),
              let rawKey = KeychainManager.read(key: "asc.privateKey") else {
            throw NSError(domain: "TestFlight", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing API credentials — configure in Xcode Cloud tab"])
        }
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

    private func mapStatus(_ processingState: Build.Attributes.ProcessingState?, betaState: BuildAudienceType?) -> Deployment.Status {
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
