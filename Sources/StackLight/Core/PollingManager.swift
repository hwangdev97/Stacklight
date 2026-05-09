import Foundation
import StackLightCore

@MainActor
final class PollingManager {
    private var timer: Timer?
    var pollInterval: TimeInterval = 60
    var onUpdate: (([Deployment]) -> Void)?
    var onError: ((String, Error) -> Void)?

    func start() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        poll()
    }

    private func poll() {
        // No-providers short-circuit must still fire onUpdate so any
        // consumer-side loading state (e.g. AppState.isRefreshing on iOS)
        // gets reset. Otherwise removing the last provider while a refresh
        // is pending leaves the Home spinner visible forever.
        guard !ServiceRegistry.shared.configuredProviders.isEmpty else {
            onUpdate?([])
            return
        }

        Task { @MainActor in
            let (sorted, errors) = await DeploymentFetcher.fetchAll(deadline: max(pollInterval, 30))
            for (providerID, error) in errors {
                self.onError?(providerID, error)
            }
            self.onUpdate?(sorted)
        }
    }
}
