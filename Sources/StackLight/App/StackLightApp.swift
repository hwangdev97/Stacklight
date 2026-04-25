import SwiftUI

@main
struct StackLightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView()
                .environmentObject(appDelegate.appState)
        } label: {
            MenuBarLabel()
                .environmentObject(appDelegate.appState)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
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

/// Wraps the SwiftUI menu content and pulls data/actions from AppState,
/// keeping `MenuBarContentView` itself free of singletons so it's easy to
/// `#Preview`.
private struct MenuBarRootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MenuBarContentView(
            providers: ServiceRegistry.shared.providers.filter { $0.isConfigured },
            deployments: appState.deployments,
            errors: appState.errors,
            lastRefresh: appState.lastRefresh,
            onRefresh: { appState.refresh() },
            onOpenSettings: {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            },
            onOpenFeedback: {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "feedback")
            },
            onCheckForUpdates: {
                Task {
                    let result: Result<UpdateCheckResult, Error>
                    do {
                        result = .success(try await UpdateChecker.checkForUpdates())
                    } catch {
                        result = .failure(error)
                    }
                    await MainActor.run {
                        UpdateChecker.presentUpdateCheckResult(result)
                    }
                }
            },
            onQuit: { NSApp.terminate(nil) }
        )
    }
}

/// The menu bar icon itself. Tints red when any provider has an error or any
/// recent deployment failed, matching the old `updateStatusIcon()` behavior.
private struct MenuBarLabel: View {
    @EnvironmentObject var appState: AppState

    private var hasProblem: Bool {
        !appState.errors.isEmpty || appState.deployments.contains { $0.status == .failed }
    }

    var body: some View {
        Image("MenubarIcon")
            .renderingMode(.template)
            .foregroundStyle(hasProblem ? Color.red : Color.primary)
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
