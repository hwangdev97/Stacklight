import Foundation
import StackLightCore
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var deployments: [Deployment] = [] {
        didSet { sortedDeployments = deployments.sorted { $0.createdAt > $1.createdAt } }
    }
    @Published private(set) var deploymentsByProvider: [String: [Deployment]] = [:]
    /// Cached sort of `deployments`. Kept in lockstep via `didSet` so views can
    /// read a stable, newest-first list from `body` without re-sorting on every
    /// render. Production write paths already produce sorted arrays, but the
    /// preview helper assigns arbitrary inputs so the resort is necessary here.
    @Published private(set) var sortedDeployments: [Deployment] = []
    @Published var errors: [String: String] = [:]
    @Published var lastRefresh: Date?
    @Published var isRefreshing: Bool = false

    /// Preview-only override for `hasConfiguredProvider`. Set in a `#Preview`
    /// helper to force Home into a specific state without touching Keychain
    /// or `UserDefaults`.
    var previewConfiguredOverride: Bool?

    private let pollingManager = PollingManager()
    private var lastPublishedFingerprint: String = ""
    private var refreshWatchdog: Task<Void, Never>?

    /// Hard cap on how long the Home spinner is allowed to stay visible.
    /// Independent of the polling deadline so a stalled fetch (slow mobile
    /// network, dropped callback) never traps the UI.
    private static let refreshUITimeout: UInt64 = 8_000_000_000 // 8s

    init() {
        // Cold-start hydration: the App Group snapshot is the same one that
        // BGAppRefresh, the widget, and the Watch read from. Restoring it here
        // means Home renders the previous deployments instantly instead of
        // showing "All Quiet" for the duration of a network round trip.
        if let snapshot = SharedStore.read() {
            self.deployments = snapshot.deployments
            self.sortedDeployments = snapshot.deployments.sorted { $0.createdAt > $1.createdAt }
            self.lastRefresh = snapshot.writtenAt
            // Seed the fingerprint so the first publishSnapshot after a no-op
            // refresh doesn't fire a redundant widget reload / Watch push.
            self.lastPublishedFingerprint = Self.fingerprint(for: snapshot.deployments)
        }
    }

    func startPolling() {
        let interval = SettingsStore.shared.pollIntervalSeconds
        pollingManager.pollInterval = interval > 0 ? interval : 60

        pollingManager.onUpdatePerProvider = { [weak self] successesByProvider in
            guard let self else { return }
            let old = self.deployments

            var merged = self.deploymentsByProvider
            for (providerID, deployments) in successesByProvider {
                merged[providerID] = deployments
            }
            let configuredIDs = Set(ServiceRegistry.shared.configuredProviders.map(\.id))
            merged = merged.filter { configuredIDs.contains($0.key) }

            let flat = merged.values
                .flatMap { $0 }
                .sorted { $0.createdAt > $1.createdAt }

            if merged != self.deploymentsByProvider {
                self.deploymentsByProvider = merged
            }
            if flat != self.deployments {
                self.deployments = flat
            }
            self.lastRefresh = Date()
            self.finishRefresh()
            NotificationManager.shared.checkForChangesPersistent(old: old, new: flat)
            self.publishSnapshot(flat)
        }
        pollingManager.onError = { [weak self] providerID, error in
            self?.errors[providerID] = error.localizedDescription
            self?.finishRefresh()
        }
        // Skip the immediate poll; scenePhase .active fires on cold start and
        // already triggers refresh(). Two callers would otherwise launch the
        // same fetch back-to-back.
        pollingManager.start(immediate: false)
    }

    func refresh() {
        errors.removeAll()
        // Without any configured provider, PollingManager.poll() short-circuits
        // and never fires onUpdate/onError — which would leave isRefreshing
        // stuck at true and the Home spinner visible forever on the empty state.
        guard hasConfiguredProvider else {
            finishRefresh()
            return
        }
        isRefreshing = true
        armRefreshWatchdog()
        pollingManager.refresh()
    }

    /// Cancel any in-flight watchdog and clear the spinner. Safe to call
    /// repeatedly (multiple providers may each fire onError before the final
    /// onUpdate arrives).
    private func finishRefresh() {
        refreshWatchdog?.cancel()
        refreshWatchdog = nil
        isRefreshing = false
    }

    /// Schedule a single-shot watchdog that force-clears `isRefreshing` if the
    /// polling pipeline never fires its callback (e.g. an unforeseen short
    /// circuit, a Task cancellation on backgrounding, or a 60s network stall
    /// that we don't want the user staring at).
    private func armRefreshWatchdog() {
        refreshWatchdog?.cancel()
        refreshWatchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.refreshUITimeout)
            guard !Task.isCancelled, let self else { return }
            self.isRefreshing = false
            self.refreshWatchdog = nil
        }
    }

    func restartPolling() {
        pollingManager.stop()
        errors.removeAll()
        startPolling()
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

        let fingerprint = Self.fingerprint(for: deployments)
        if fingerprint != lastPublishedFingerprint {
            lastPublishedFingerprint = fingerprint
            WidgetRefresh.reloadAll()
            // Also fire a guaranteed-delivery transfer so the Watch reloads its
            // complications even if the `applicationContext` is coalesced away.
            PhoneSessionManager.shared.notifyStatusChange(snapshot: snapshot)
        }
    }

    private static func fingerprint(for deployments: [Deployment]) -> String {
        deployments
            .map { "\($0.providerID):\($0.id):\($0.status.rawValue)" }
            .sorted()
            .joined(separator: "|")
    }
}
