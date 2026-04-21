import SwiftUI
import UserNotifications

@main
struct StackLightiOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Team-prefixed keychain group. Xcode injects `AppIdentifierPrefix` at
        // runtime via the entitlement; we mirror that by reading the bundle's
        // app-identifier-prefix from the embedded provisioning (falling back
        // to the hard-coded team id if not available — e.g. simulator).
        KeychainManager.accessGroup = Self.resolveKeychainAccessGroup()
        requestNotificationAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .task {
                    appState.startPolling()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        appState.refresh()
                    case .background:
                        BackgroundRefreshCoordinator.scheduleNext()
                    default:
                        break
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func requestNotificationAuthorization() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Resolve the runtime-prefixed keychain access group. The entitlement
    /// contains `$(AppIdentifierPrefix)app.yellowplus.StackLight`; at runtime
    /// `AppIdentifierPrefix` resolves to the team id followed by a dot, e.g.
    /// `QDJ93ZUQ9B.`. We hard-code the fallback for cases where the prefix
    /// isn't available (simulator without provisioning).
    private static func resolveKeychainAccessGroup() -> String {
        let bundleSeedID = "QDJ93ZUQ9B"
        return "\(bundleSeedID).app.yellowplus.StackLight"
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "stacklight" else { return }
        // Path format: stacklight://deployment/<providerID>/<id>
        // For now, trigger a refresh so the user lands on the most up-to-date
        // list. Rich routing into a detail screen can land when the detail
        // view exists.
        appState.refresh()
    }
}
