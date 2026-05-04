import Foundation
import StackLightCore

@MainActor
final class AppState: ObservableObject {
    @Published var deployments: [Deployment] = []
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
        let diag = AppConfig.defaults.bool(forKey: "diagnosticsEnabled")
        let fileLog = AppConfig.defaults.bool(forKey: "fileLoggingEnabled")
        Task {
            await DiagnosticsLogger.shared.setEnabled(diag)
            await DiagnosticsLogger.shared.setFileLogging(fileLog)
        }
    }

    func startPolling() {
        // Read poll interval from settings
        let interval = AppConfig.defaults.double(forKey: "pollInterval")
        pollingManager.pollInterval = interval > 0 ? interval : 60

        pollingManager.onUpdate = { [weak self] newDeployments in
            guard let self else { return }
            let oldDeployments = self.deployments
            self.deployments = newDeployments
            self.lastRefresh = Date()
            self.recomputeRefreshSummary()
            NotificationManager.shared.checkForChangesPersistent(old: oldDeployments, new: newDeployments)
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
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: at, relativeTo: Date())
    }

    var menuLine: String {
        "Last refresh: \(ageFragment) · \(statusFragment)"
    }
}
