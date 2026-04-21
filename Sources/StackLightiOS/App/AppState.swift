import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var deployments: [Deployment] = []
    @Published var errors: [String: String] = [:]
    @Published var lastRefresh: Date?
    @Published var isRefreshing: Bool = false

    /// Preview-only override for `hasConfiguredProvider`. Set in a `#Preview`
    /// helper to force Home into a specific state without touching Keychain
    /// or `UserDefaults`.
    var previewConfiguredOverride: Bool?

    private let pollingManager = PollingManager()
    private var lastPublishedFingerprint: String = ""

    func startPolling() {
        let interval = AppConfig.defaults.double(forKey: "pollInterval")
        pollingManager.pollInterval = interval > 0 ? interval : 60

        pollingManager.onUpdate = { [weak self] newDeployments in
            guard let self else { return }
            let old = self.deployments
            self.deployments = newDeployments
            self.lastRefresh = Date()
            self.isRefreshing = false
            NotificationManager.shared.checkForChangesPersistent(old: old, new: newDeployments)
            self.publishSnapshot(newDeployments)
        }
        pollingManager.onError = { [weak self] providerID, error in
            self?.errors[providerID] = error.localizedDescription
            self?.isRefreshing = false
        }
        pollingManager.start()
    }

    func refresh() {
        errors.removeAll()
        isRefreshing = true
        pollingManager.refresh()
    }

    func restartPolling() {
        pollingManager.stop()
        errors.removeAll()
        startPolling()
    }

    /// Convenience: deployments sorted newest-first across all providers.
    var sortedDeployments: [Deployment] {
        deployments.sorted { $0.createdAt > $1.createdAt }
    }

    /// Whether at least one provider has valid credentials.
    var hasConfiguredProvider: Bool {
        if let override = previewConfiguredOverride { return override }
        return !ServiceRegistry.shared.configuredProviders.isEmpty
    }

    /// Write the current deployments to the shared App Group container and
    /// ping the widget timeline if the status fingerprint changed.
    private func publishSnapshot(_ deployments: [Deployment]) {
        SharedStore.write(deployments: deployments)
        let fingerprint = deployments
            .map { "\($0.providerID):\($0.id):\($0.status.rawValue)" }
            .sorted()
            .joined(separator: "|")
        if fingerprint != lastPublishedFingerprint {
            lastPublishedFingerprint = fingerprint
            WidgetRefresh.reloadAll()
        }
    }
}
