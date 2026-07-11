import Foundation
import StackLightCore

@MainActor
final class AppState: ObservableObject {
    @Published var deployments: [Deployment] = []
    /// Pre-grouped view of `deployments` keyed by provider ID. Maintained in
    /// lockstep with `deployments` so the menu UI doesn't have to call
    /// `Dictionary(grouping:)` on every body re-evaluation.
    @Published private(set) var deploymentsByProvider: [String: [Deployment]] = [:]
    @Published var errors: [String: String] = [:] // providerID -> error message
    @Published var lastRefresh: Date?
    /// Most recent batch outcome for the menu header line. `nil` until first
    /// poll completes.
    @Published var lastRefreshSummary: RefreshSummary?

    var openSettingsWindow: (() -> Void)?
    var openFeedbackWindow: (() -> Void)?

    private let pollingManager = PollingManager()

    init() {
        // Replay diagnostics toggle into the singleton on cold launch so logs
        // start flowing immediately if the user enabled it last session.
        let store = SettingsStore.shared
        let diag = store.diagnosticsEnabled
        let fileLog = store.fileLoggingEnabled
        let verbosity = store.loggingVerbosity
        Task {
            await DiagnosticsLogger.shared.setEnabled(diag)
            await DiagnosticsLogger.shared.setFileLogging(fileLog)
            await DiagnosticsLogger.shared.setVerbosity(verbosity)
        }
    }

    func startPolling() {
        let interval = SettingsStore.shared.pollIntervalSeconds
        pollingManager.pollInterval = interval > 0 ? interval : 60

        pollingManager.onUpdatePerProvider = { [weak self] successesByProvider in
            guard let self else { return }
            let oldDeployments = self.deployments

            // Merge per-provider: providers that succeeded this pass overwrite
            // their slice; providers that errored or were dropped at the
            // deadline keep their previous deployments (stale but informative)
            // so the menu doesn't blink rows out on a transient failure.
            // Configured providers that have *no* slice yet remain absent.
            var merged = self.deploymentsByProvider
            for (providerID, deployments) in successesByProvider {
                merged[providerID] = deployments
            }
            // Drop any provider that's no longer configured so removing a
            // service from Settings actually clears its rows.
            let configuredIDs = Set(ServiceRegistry.shared.configuredProviders.map(\.id))
            merged = merged.filter { configuredIDs.contains($0.key) }

            let flat = merged.values
                .flatMap { $0 }
                .sorted { $0.createdAt > $1.createdAt }

            // Skip the @Published assignment when nothing changed — avoids
            // triggering objectWillChange (which forces a SwiftUI rebuild
            // tree-wide) on identical poll results, the common steady-state.
            if merged != self.deploymentsByProvider {
                self.deploymentsByProvider = merged
            }
            if flat != self.deployments {
                self.deployments = flat
            }
            self.lastRefresh = Date()
            self.recomputeRefreshSummary()
            NotificationManager.shared.checkForChangesPersistent(old: oldDeployments, new: flat)
        }
        pollingManager.onError = { [weak self] providerID, error in
            self?.errors[providerID] = error.localizedDescription
            self?.recomputeRefreshSummary()
        }
        pollingManager.start()
    }

    func refresh() {
        errors.removeAll()
        pollingManager.refresh()
    }

    func restartPolling() {
        pollingManager.stop()
        errors.removeAll()
        startPolling()
    }

    private func recomputeRefreshSummary() {
        let configuredCount = ServiceRegistry.shared.configuredProviders.count
        let okCount = max(0, configuredCount - errors.count)
        lastRefreshSummary = RefreshSummary(
            okCount: okCount,
            errorCount: errors.count,
            total: configuredCount,
            at: lastRefresh ?? Date()
        )
    }
}

/// Compact rollup shown in the menu bar header: "12s ago · 8/9 ok".
struct RefreshSummary: Equatable {
    let okCount: Int
    let errorCount: Int
    let total: Int
    let at: Date

    var statusFragment: String {
        "\(okCount)/\(total) ok"
    }

    var ageFragment: String {
        SharedFormatters.relativeAbbreviated.localizedString(for: at, relativeTo: Date())
    }

    var menuLine: String {
        "Last refresh: \(ageFragment) · \(statusFragment)"
    }
}
