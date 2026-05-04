import WidgetKit
import StackLightCore
import Foundation

/// Complication timeline provider. The Watch app doesn't talk to providers
/// directly — it only consumes the snapshot the paired iPhone pushes via
/// WatchConnectivity. This provider is therefore read-only: it renders
/// whatever `SharedStore` currently holds and lets the `WKApplicationRefresh`
/// path (plus push-driven `reloadAllTimelines()`) keep it fresh.
struct WatchDeploymentProvider: TimelineProvider {
    /// Cadence while any build is active — we want frequent samples so the
    /// complication visibly transitions when the state lands.
    private let activeReloadInterval: TimeInterval = 60
    /// Cadence when everything is stable — watchOS won't honor a tighter
    /// schedule anyway, so there's no point asking for one.
    private let stableReloadInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> WatchDeploymentEntry {
        WatchDeploymentEntry.placeholder()
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (WatchDeploymentEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<WatchDeploymentEntry>) -> Void) {
        let now = Date()
        let entry = currentEntry(date: now)
        let interval = entry.activeBuild ? activeReloadInterval : stableReloadInterval
        let stepCount = entry.activeBuild ? 5 : 4

        var entries: [WatchDeploymentEntry] = []
        for step in 0..<stepCount {
            let stepDate = now.addingTimeInterval(interval * Double(step))
            entries.append(WatchDeploymentEntry(
                date: stepDate,
                deployments: entry.deployments,
                activeBuild: entry.activeBuild,
                writtenAt: entry.writtenAt
            ))
        }

        let reloadAt = now.addingTimeInterval(interval)
        completion(Timeline(entries: entries, policy: .after(reloadAt)))
    }

    private func currentEntry(date: Date = Date()) -> WatchDeploymentEntry {
        let snapshot = SharedStore.read()
        let deployments = (snapshot?.deployments ?? [])
            .sorted { $0.createdAt > $1.createdAt }
        let active = deployments.contains { $0.status == .building || $0.status == .queued }
        return WatchDeploymentEntry(
            date: date,
            deployments: deployments,
            activeBuild: active,
            writtenAt: snapshot?.writtenAt
        )
    }
}
