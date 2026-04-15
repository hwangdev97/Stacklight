import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var deployments: [Deployment] = []
    @Published var errors: [String: String] = [:]
    @Published var lastRefresh: Date?
    @Published var isRefreshing: Bool = false

    private let pollingManager = PollingManager()
    private let notificationManager = NotificationManager()

    func startPolling() {
        let interval = UserDefaults.standard.double(forKey: "pollInterval")
        pollingManager.pollInterval = interval > 0 ? interval : 60

        pollingManager.onUpdate = { [weak self] newDeployments in
            guard let self else { return }
            let old = self.deployments
            self.deployments = newDeployments
            self.lastRefresh = Date()
            self.isRefreshing = false
            self.notificationManager.checkForChanges(old: old, new: newDeployments)
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
        !ServiceRegistry.shared.configuredProviders.isEmpty
    }
}
