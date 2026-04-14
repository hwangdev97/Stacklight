import SwiftUI

@main
struct StackLightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("StackLight Settings", id: "settings") {
            SettingsViewContainer()
                .environmentObject(appDelegate.appState)
        }
        .defaultSize(width: 660, height: 500)
        .windowResizability(.contentSize)

        Window("Send Feedback", id: "feedback") {
            FeedbackWindowContent()
                .environmentObject(appDelegate.appState)
        }
        .defaultSize(width: 560, height: 520)
        .windowResizability(.contentSize)
    }
}

/// Wrapper that captures the SwiftUI `openWindow` environment action
/// and stores it on AppState so AppDelegate can trigger it from NSMenu.
private struct SettingsViewContainer: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var appState: AppState

    var body: some View {
        SettingsView()
            .onAppear {
                appState.openSettingsWindow = { [openWindow] in
                    openWindow(id: "settings")
                }
            }
    }
}
