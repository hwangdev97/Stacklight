import SwiftUI

@main
struct ShapeBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("ShapeBar Settings", id: "settings") {
            SettingsViewContainer()
                .environmentObject(appDelegate.appState)
        }
        .defaultSize(width: 660, height: 500)
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
