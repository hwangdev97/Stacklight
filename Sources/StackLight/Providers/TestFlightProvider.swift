import Foundation
import SwiftUI
import AppStoreConnect_Swift_SDK

final class TestFlightProvider: DeploymentProvider {
    let id = "testFlight"
    let displayName = "TestFlight"
    let iconSymbol = "airplane"
    let color = Color(red: 0.25, green: 0.65, blue: 0.96)
    let docsURL = URL(string: "https://appstoreconnect.apple.com/apps")

    init() {
        AppConfig.migrateSingleToMulti(oldKey: "testflight.appId", newKey: "testflight.appIds")
    }

    var dashboardURL: URL? {
        let ids = parsedAppIds()
        if ids.count == 1 {
            return URL(string: "https://appstoreconnect.apple.com/apps/\(ids[0])/testflight/ios")
        }
        return URL(string: "https://appstoreconnect.apple.com/apps")
    }

    var isConfigured: Bool {
        guard ASCCredentialStore.current() != nil else { return false }
        return !parsedAppIds().isEmpty
    }

    func fetchDeployments() async throws -> DeploymentFetchResult {
        let appIds = parsedAppIds()
        guard !appIds.isEmpty else { return .empty }

        let provider = try makeProvider()

        // One quick batch call resolves every configured App ID to its
        // display name. A transient failure here just drops us back to the
        // version-only label; it shouldn't take down the per-app fan-out.
        let appNames: [String: String] = (try? await fetchAppNames(provider: provider, appIds: appIds)) ?? [:]

        return await DeploymentFetchResult.collecting(appIds, name: { $0 }) { appId in
            try await Self.fetchBuilds(provider: provider, appId: appId, appName: appNames[appId])
        }
    }

    func settingsFields() -> [SettingsField] {
        [
            SettingsField(
                key: "testflight.appIds",
                label: "App IDs",
                placeholder: "12345, 67890",
                isMultiValue: true,
                hint: "API credentials are shared with Xcode Cloud — configure them in the Xcode Cloud tab first"
            )
        ]
    }

    // MARK: - Helpers

    private func parsedAppIds() -> [String] {
        (AppConfig.defaults.string(forKey: "testflight.appIds") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func fetchAppNames(provider: APIProvider, appIds: [String]) async throws -> [String: String] {
        let request = APIEndpoint
            .v1
            .apps
            .get(parameters: .init(filterId: appIds, limit: max(appIds.count, 1)))
        let response = try await provider.request(request)
        var map: [String: String] = [:]
        for app in response.data {
            if let name = app.attributes?.name {
                map[app.id] = name
            }
        }
        return map
    }

    private static func fetchBuilds(provider: APIProvider, appId: String, appName: String?) async throws -> [Deployment] {
        let request = APIEndpoint
            .v1
            .builds
            .get(parameters: .init(
                filterApp: [appId],
                sort: [.minusuploadedDate],
                limit: 10
            ))

        let response = try await provider.request(request)
        return response.data.compactMap { build -> Deployment? in
            guard let attrs = build.attributes else { return nil }
            let version = attrs.version ?? "?"
            let label: String
            if let appName, !appName.isEmpty {
                label = "\(appName) v\(version)"
            } else {
                label = "v\(version)"
            }
            return Deployment(
                id: build.id,
                providerID: "testFlight",
                projectName: label,
                status: mapStatus(attrs.processingState, betaState: attrs.buildAudienceType),
                url: nil,
                createdAt: attrs.uploadedDate ?? Date(),
                commitMessage: nil,
                branch: nil
            )
        }
    }

    private func makeProvider() throws -> APIProvider {
        guard let credentials = ASCCredentialStore.current() else {
            throw NSError(domain: "TestFlight", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing API credentials — configure in Xcode Cloud tab"])
        }
        let config = try APIConfiguration(
            issuerID: credentials.issuerID,
            privateKeyID: credentials.keyID,
            privateKey: credentials.privateKey
        )
        return APIProvider(configuration: config)
    }

    private static func mapStatus(_ processingState: Build.Attributes.ProcessingState?, betaState: BuildAudienceType?) -> Deployment.Status {
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
