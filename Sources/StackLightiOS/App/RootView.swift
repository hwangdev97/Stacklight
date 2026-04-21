import SwiftUI

/// Top-level shell that picks between the compact (iPhone / iPad Slide Over)
/// and regular (iPad full-screen / Split View) layouts at runtime.
///
/// Compact stays on the existing single-column `HomeView`. Regular swaps in
/// the sidebar + detail `HomeSplitView` so the iPad can actually use its
/// screen real estate.
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                HomeSplitView()
            } else {
                HomeView()
            }
        }
    }
}

#if DEBUG
#Preview("Regular") {
    RootView()
        .environmentObject(AppState())
        .environment(\.horizontalSizeClass, .regular)
}

#Preview("Compact") {
    RootView()
        .environmentObject(AppState())
        .environment(\.horizontalSizeClass, .compact)
}
#endif
