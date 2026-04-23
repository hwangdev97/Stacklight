import WatchKit

/// Runs at launch to activate the `WCSession` and register the background
/// refresh handler. Both must be wired synchronously during launch — delaying
/// either causes the first transfer/refresh to be dropped.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        WatchSessionManager.shared.activate()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        WatchRefreshScheduler.handle(backgroundTasks)
    }
}
