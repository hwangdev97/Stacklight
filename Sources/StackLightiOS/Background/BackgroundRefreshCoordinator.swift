import Foundation
import StackLightCore
import BackgroundTasks
import UserNotifications

/// Owns the iOS `BGAppRefreshTask` lifecycle. iOS wakes the app opportunistically
/// (no sooner than 15 minutes, timing controlled by the system) so we can poll
/// providers and surface local notifications while the app is backgrounded.
/// If the user force-quits the app or the device is unlocked-pending-reboot,
/// iOS will not launch us — this is a platform limitation, not something the
/// app can work around without a push-capable backend.
@MainActor
enum BackgroundRefreshCoordinator {
    static let identifier = BackgroundRefreshIdentifiers.appRefresh

    // iOS clamps `earliestBeginDate` to at least 15 minutes regardless of
    // what we submit, so there's no point scheduling sooner.
    static let minInterval: TimeInterval = 15 * 60

    /// Must be called synchronously during app launch, before the first
    /// runloop tick. Registering later makes iOS throw when it tries to
    /// launch the app for a pending task.
    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: nil
        ) { task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await handle(task: task)
            }
        }
    }

    /// Submit a new refresh request. Safe to call repeatedly — iOS replaces
    /// any outstanding request with this identifier.
    static func scheduleNext() {
        let configured = AppConfig.defaults.double(forKey: "pollInterval")
        let desired = configured > 0 ? configured : 60
        let earliest = max(desired, minInterval)

        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: earliest)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(task: BGAppRefreshTask) async {
        // Reschedule up-front so a mid-handler failure doesn't break the chain.
        scheduleNext()

        let work = Task { @MainActor () -> Bool in
            // Give ourselves a 25s budget — BGAppRefreshTask is capped at ~30s,
            // so leave headroom for the post-fetch diff + plist write.
            let (fresh, _) = await DeploymentFetcher.fetchAll(deadline: 25)
            guard !fresh.isEmpty else { return false }

            let old = SharedStore.read()?.deployments ?? []
            NotificationManager.shared.checkForChangesPersistent(old: old, new: fresh)
            SharedStore.write(deployments: fresh)
            WidgetRefresh.reloadAll()
            return true
        }

        task.expirationHandler = { work.cancel() }

        let success = await work.value
        task.setTaskCompleted(success: success)
    }
}
