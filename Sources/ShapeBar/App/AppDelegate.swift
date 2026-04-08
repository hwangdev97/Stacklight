import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        UNUserNotificationCenter.current().delegate = self

        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "triangleshape.fill",
                                   accessibilityDescription: "ShapeBar")
        }

        // Build initial menu
        rebuildMenu()

        // Wire up state changes to menu rebuilds + icon updates
        appState.onDeploymentsChanged = { [weak self] in
            self?.rebuildMenu()
            self?.updateStatusIcon()
        }

        // Start polling
        appState.startPolling()
    }

    func rebuildMenu() {
        let menu = MenuBuilder.buildMenu(
            deployments: appState.deployments,
            errors: appState.errors,
            lastRefresh: appState.lastRefresh,
            target: self
        )
        statusItem.menu = menu
    }

    func updateStatusIcon() {
        let hasErrors = !appState.errors.isEmpty
        let hasFailedDeploy = appState.deployments.contains { $0.status == .failed }

        if hasErrors || hasFailedDeploy {
            var image = NSImage(systemSymbolName: "triangleshape.fill", accessibilityDescription: "ShapeBar")
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            image = image?.withSymbolConfiguration(config)
            statusItem.button?.image = image
        } else {
            statusItem.button?.image = NSImage(systemSymbolName: "triangleshape.fill", accessibilityDescription: "ShapeBar")
        }
    }

    @objc func openDeploymentURL(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func refreshNow(_ sender: NSMenuItem) {
        appState.refresh()
    }

    @objc func openSettings(_ sender: NSMenuItem) {
        // Try to find existing window first (SwiftUI Window scene creates it lazily)
        if let window = NSApp.windows.first(where: { $0.title == "ShapeBar Settings" }) {
            window.makeKeyAndOrderFront(nil)
        } else if let openWindow = appState.openSettingsWindow {
            // Use captured SwiftUI openWindow action
            openWindow()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }
}

// MARK: - Notification Handling

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let urlString = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
