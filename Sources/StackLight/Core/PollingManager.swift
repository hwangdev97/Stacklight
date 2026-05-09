import Foundation
import StackLightCore

@MainActor
final class PollingManager {
    private var timer: Timer?
    var pollInterval: TimeInterval = 60

    /// Called once per poll with the providers that succeeded, after errors
    /// for that pass have already been forwarded via `onError`. The dictionary
    /// only contains providers that completed without throwing — failed ones
    /// are omitted so the consumer can choose to keep stale data instead of
    /// wiping rows on a transient error.
    var onUpdatePerProvider: (([String: [Deployment]]) -> Void)?
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
        // No-providers short-circuit must still fire onUpdatePerProvider so
        // any consumer-side loading state (e.g. AppState.isRefreshing on iOS)
        // gets reset. Otherwise removing the last provider while a refresh
        // is pending leaves the Home spinner visible forever.
        guard !ServiceRegistry.shared.configuredProviders.isEmpty else {
            onUpdatePerProvider?([:])
            return
        }

        Task { @MainActor in
            let batch = await DeploymentFetcher.fetchAllPerProvider(
                deadline: max(pollInterval, 30)
            )
            for (providerID, error) in batch.errors {
                self.onError?(providerID, error)
            }
            self.onUpdatePerProvider?(batch.successes)
        }
    }
}
