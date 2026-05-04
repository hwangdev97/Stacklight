import SwiftUI
import StackLightCore

/// iPad-only (regular width) home shell. Two-column `NavigationSplitView`:
/// sidebar = provider filter + setup actions; detail = deployment grid.
/// Sheets (Settings, AddIntegration, Safari) are presented from the detail.
struct HomeSplitView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedProviderID: String? = nil
    @State private var showSettings = false
    @State private var showAddIntegration = false
    @State private var safariTarget: SafariTarget?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                selectedProviderID: $selectedProviderID,
                onOpenSettings: { showSettings = true },
                onAddIntegration: { showAddIntegration = true }
            )
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            NavigationStack {
                DeploymentGridView(
                    selectedProviderID: selectedProviderID,
                    onOpenURL: { url in safariTarget = SafariTarget(url: url) },
                    onAddIntegration: { showAddIntegration = true }
                )
                .toolbar { toolbarContent }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(.dark)
        .tint(.white)
        .sheet(isPresented: $showSettings) {
            SettingsSplitView().environmentObject(appState)
        }
        .sheet(isPresented: $showAddIntegration) {
            AddIntegrationView().environmentObject(appState)
        }
        .sheet(item: $safariTarget) { target in
            SafariView(url: target.url).ignoresSafeArea()
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .keyboardShortcut(",", modifiers: .command)
            .accessibilityLabel("Settings")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                appState.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .keyboardShortcut("r", modifiers: .command)
            .accessibilityLabel("Refresh")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showAddIntegration = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityLabel("Add Integration")
        }
    }
}

#if DEBUG
#Preview {
    HomeSplitView()
        .environmentObject(AppState())
}
#endif
