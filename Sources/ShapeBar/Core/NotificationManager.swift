import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    private var previousStates: [String: Deployment.Status] = [:]

    func checkForChanges(old: [Deployment], new: [Deployment]) {
        guard UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true else {
            updateStates(from: new)
            return
        }

        // Skip notifications on first load (no previous data)
        guard !previousStates.isEmpty else {
            updateStates(from: new)
            return
        }

        for deployment in new {
            guard let oldStatus = previousStates[deployment.id] else { continue }
            let newStatus = deployment.status

            // Only notify on meaningful transitions
            if oldStatus != newStatus {
                switch newStatus {
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

        updateStates(from: new)
    }

    private func updateStates(from deployments: [Deployment]) {
        previousStates = Dictionary(
            deployments.map { ($0.id, $0.status) },
            uniquingKeysWith: { _, last in last }
        )
    }

    private func formatBody(_ deployment: Deployment) -> String {
        var parts = [deployment.projectName]
        if let branch = deployment.branch {
            parts.append("on \(branch)")
        }
        return parts.joined(separator: " ")
    }

    private func sendNotification(title: String, body: String, deployment: Deployment) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let url = deployment.url {
            content.userInfo = ["url": url.absoluteString]
        }

        let request = UNNotificationRequest(
            identifier: "shapebar.\(deployment.id).\(deployment.status.rawValue)",
            content: content,
            trigger: nil // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}
