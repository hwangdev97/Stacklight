import Foundation
import StackLightCore
import Combine

@MainActor
final class WatchAppState: ObservableObject {
    @Published private(set) var deployments: [Deployment] = []
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var isRefreshing: Bool = false

    private var cancellable: AnyCancellable?

    init() {
        loadFromStore()
        cancellable = NotificationCenter.default
            .publisher(for: WatchSessionManager.snapshotDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in self?.loadFromStore() }
            }
    }

    var sortedDeployments: [Deployment] {
        deployments.sorted { $0.createdAt > $1.createdAt }
    }

    /// Pull the latest snapshot straight from the paired iPhone. Falls through
    /// silently when the iPhone is unreachable — the UI keeps the last known
    /// state, which is the expected behavior on a thin client.
    func refresh() {
        isRefreshing = true
        WatchSessionManager.shared.requestSnapshot { [weak self] ok in
            Task { @MainActor in
                self?.isRefreshing = false
                if ok { self?.loadFromStore() }
            }
        }
    }

    private func loadFromStore() {
        guard let snapshot = SharedStore.read() else {
            deployments = []
            lastRefresh = nil
            return
        }
        deployments = snapshot.deployments
        lastRefresh = snapshot.writtenAt
    }
}
