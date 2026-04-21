import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    /// Diffs `new` against both `old` (in-memory prior poll result) and the
    /// persisted `NotifiedStateStore`, firing a local notification for each
    /// meaningful transition. Persisted state is the authoritative dedupe key
    /// so a status change delivered in the foreground isn't re-announced when
    /// iOS wakes the app in the background, and vice versa.
    func checkForChangesPersistent(old: [Deployment], new: [Deployment]) {
        let enabled = AppConfig.defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        var notified = NotifiedStateStore.read()
        let firstRun = notified.isEmpty

        if enabled && !firstRun {
            for deployment in new {
                let stateKey = NotifiedStateStore.key(for: deployment)
                let lastRaw = notified[stateKey]
                let newRaw = deployment.status.rawValue
                guard lastRaw != newRaw else { continue }

                let oldStatus: Deployment.Status? =
                    old.first(where: { $0.id == deployment.id })?.status
                    ?? lastRaw.flatMap { Deployment.Status(rawValue: $0) }

                switch deployment.status {
                case .failed:
                    sendNotification(
                        title: "Deploy Failed",
                        body: formatBody(deployment),
                        deployment: deployment
                    )
                case .success where oldStatus == .building:
                    sendNotification(
                        title: "Deploy Ready",
                        body: formatBody(deployment),
                        deployment: deployment
                    )
                default:
                    break
                }
            }
        }

        for deployment in new {
            notified[NotifiedStateStore.key(for: deployment)] = deployment.status.rawValue
        }
        let liveKeys = Set(new.map { NotifiedStateStore.key(for: $0) })
        notified = notified.filter { liveKeys.contains($0.key) }
        NotifiedStateStore.write(notified)
    }

    private func formatBody(_ deployment: Deployment) -> String {
        var parts = [deployment.projectName]
        if let branch = deployment.branch {
            parts.append("on \(branch)")
        }
        return parts.joined(separator: " ")
    }

    private func sendNotification(title: String, body: String, deployment: Deployment) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let url = deployment.url {
            content.userInfo = ["url": url.absoluteString]
        }

        let request = UNNotificationRequest(
            identifier: "stacklight.\(deployment.id).\(deployment.status.rawValue)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
