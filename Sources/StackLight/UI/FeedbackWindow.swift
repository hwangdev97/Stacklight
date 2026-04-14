import SwiftUI

/// Wrapper that captures the SwiftUI `openWindow` environment action
/// and stores it on AppState so AppDelegate can trigger it from NSMenu.
struct FeedbackWindowContent: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var appState: AppState

    var body: some View {
        FeedbackView()
            .frame(width: 560, height: 520)
            .onAppear {
                appState.openFeedbackWindow = { [openWindow] in
                    openWindow(id: "feedback")
                }
            }
    }
}
