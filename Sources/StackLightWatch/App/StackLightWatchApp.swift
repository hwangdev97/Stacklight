import SwiftUI
import StackLightCore

@main
struct StackLightWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate
    @StateObject private var appState = WatchAppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                DeploymentListView()
            }
            .environmentObject(appState)
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    appState.refresh()
                case .background:
                    WatchRefreshScheduler.scheduleNext()
                default:
                    break
                }
            }
        }
    }
}
