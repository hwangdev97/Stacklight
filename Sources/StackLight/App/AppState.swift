import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var deployments: [Deployment] = []
    @Published var errors: [String: String] = [:] // providerID -> error message
    @Published var lastRefresh: Date?

    var openSettingsWindow: (() -> Void)?
    var openFeedbackWindow: (() -> Void)?

    private let pollingManager = PollingManager()
    private let notificationManager = NotificationManager()

    func startPolling() {
        // Read poll interval from settings
        let interval = UserDefaults.standard.double(forKey: "pollInterval")
        pollingManager.pollInterval = interval > 0 ? interval : 60

        pollingManager.onUpdate = { [weak self] newDeployments in
            guard let self else { return }
            let oldDeployments = self.deployments
            self.deployments = newDeployments
            self.lastRefresh = Date()
            self.notificationManager.checkForChanges(old: oldDeployments, new: newDeployments)
        }
        pollingManager.onError = { [weak self] providerID, error in
            self?.errors[providerID] = error.localizedDescription
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
}
