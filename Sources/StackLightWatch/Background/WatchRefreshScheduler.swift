import Foundation
import WatchKit
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Owns `WKApplicationRefreshBackgroundTask`. When iOS pairs with the watch
/// and the watch is on the wrist, the system periodically hands us a slice to
/// refresh data for complications. We use it to pull the freshest snapshot
/// from the iPhone (when reachable) and reload timelines. Budget is tight —
/// the handler commonly has well under 10s of wall time.
enum WatchRefreshScheduler {
    /// Minimum interval we ask the system for. WatchOS clamps this to its own
    /// schedule anyway — realistic cadence ends up around 5–15 minutes.
    private static let preferredInterval: TimeInterval = 15 * 60

    /// Age beyond which we consider the on-disk snapshot stale enough to
    /// spend our background slot refreshing it.
    private static let freshEnough: TimeInterval = 5 * 60

    static func scheduleNext() {
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date(timeIntervalSinceNow: preferredInterval),
            userInfo: nil
        ) { _ in
            // Errors are non-actionable; the system will re-admit us later.
        }
    }

    static func handle(_ tasks: Set<WKRefreshBackgroundTask>) {
        for task in tasks {
            switch task {
            case let refresh as WKApplicationRefreshBackgroundTask:
                handleAppRefresh(refresh)
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    private static func handleAppRefresh(_ task: WKApplicationRefreshBackgroundTask) {
        scheduleNext()

        let writtenAt = SharedStore.read()?.writtenAt
        let isFresh = writtenAt.map { Date().timeIntervalSince($0) < freshEnough } ?? false

        guard !isFresh else {
            reloadAllComplications()
            task.setTaskCompletedWithSnapshot(false)
            return
        }

        WatchSessionManager.shared.requestSnapshot { _ in
            reloadAllComplications()
            task.setTaskCompletedWithSnapshot(false)
        }
    }

    private static func reloadAllComplications() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
