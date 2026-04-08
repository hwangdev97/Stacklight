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
            button.image = NSImage(systemSymbolName: "shippingbox.fill",
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
        let aggregate = aggregateStatus(from: appState.deployments)
        let (symbolName, color) = iconForStatus(aggregate)

        var image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "ShapeBar")
        if let color {
            let config = NSImage.SymbolConfiguration(paletteColors: [color])
            image = image?.withSymbolConfiguration(config)
        }
        statusItem.button?.image = image
    }

    private func aggregateStatus(from deployments: [Deployment]) -> Deployment.Status? {
        guard !deployments.isEmpty else { return nil }
        // Priority: failed > building > reviewing > queued > success
        let priority: [Deployment.Status] = [.failed, .building, .reviewing, .queued, .success]
        let statuses = Set(deployments.map(\.status))
        return priority.first { statuses.contains($0) }
    }

    private func iconForStatus(_ status: Deployment.Status?) -> (String, NSColor?) {
        switch status {
        case .failed:    return ("exclamationmark.triangle.fill", .systemRed)
        case .building:  return ("arrow.triangle.2.circlepath", .systemOrange)
        case .reviewing: return ("eye.circle.fill", .systemBlue)
        case .queued:    return ("clock.fill", .systemGray)
        case .success:   return ("checkmark.circle.fill", .systemGreen)
        default:         return ("shippingbox.fill", nil)
        }
    }

    @objc func openDeploymentURL(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func refreshNow(_ sender: NSMenuItem) {
        appState.refresh()
    }

    var settingsWindow: NSWindow?

    @objc func openSettings(_ sender: NSMenuItem) {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(appState)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ShapeBar Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
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
        // Open deployment URL when notification is clicked
        if let urlString = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        completionHandler()
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
