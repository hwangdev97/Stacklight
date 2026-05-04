import Foundation
import StackLightCore
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
        // Without any configured provider, PollingManager.poll() short-circuits
        // and never fires onUpdate/onError — which would leave isRefreshing
        // stuck at true and the Home spinner visible forever on the empty state.
        guard hasConfiguredProvider else {
            isRefreshing = false
            return
        }
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

    /// Sorted deployments filtered to a single provider, or all of them when
    /// `providerID` is `nil`. Shared between Home's compact list and the
    /// iPad grid.
    func filteredDeployments(for providerID: String?) -> [Deployment] {
        guard let providerID else { return sortedDeployments }
        return sortedDeployments.filter { $0.providerID == providerID }
    }

    /// Configured providers that have actually produced deployments in this
    /// session. Used for filter UIs so we don't list services with no data.
    var activeProviderIDs: [String] {
        let configured = ServiceRegistry.shared.configuredProviders.map(\.id)
        let withData = Set(sortedDeployments.map(\.providerID))
        return configured.filter { withData.contains($0) }
    }

    /// Whether at least one provider has valid credentials.
    var hasConfiguredProvider: Bool {
        if let override = previewConfiguredOverride { return override }
        return !ServiceRegistry.shared.configuredProviders.isEmpty
    }

    /// Write the current deployments to the shared App Group container, ping
    /// the widget timeline on status changes, and keep the paired Apple Watch
    /// in sync over WatchConnectivity.
    private func publishSnapshot(_ deployments: [Deployment]) {
        let snapshot = SharedStore.Snapshot(deployments: deployments)
        SharedStore.write(snapshot)
        PhoneSessionManager.shared.push(snapshot: snapshot)

        let fingerprint = deployments
            .map { "\($0.providerID):\($0.id):\($0.status.rawValue)" }
            .sorted()
            .joined(separator: "|")
        if fingerprint != lastPublishedFingerprint {
            lastPublishedFingerprint = fingerprint
            WidgetRefresh.reloadAll()
            // Also fire a guaranteed-delivery transfer so the Watch reloads its
            // complications even if the `applicationContext` is coalesced away.
            PhoneSessionManager.shared.notifyStatusChange(snapshot: snapshot)
        }
    }
}
