import SwiftUI
import StackLightCore

/// Sidebar used by `HomeSplitView` on iPad. Acts as the provider filter
/// (replacing the horizontal pill rail from the compact layout) plus the
/// entry points for Settings and Add Integration.
struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    /// `nil` = show deployments from every provider.
    @Binding var selectedProviderID: String?

    /// Invoked when the user taps the Settings row in the sidebar footer.
    var onOpenSettings: () -> Void
    /// Invoked when the user taps the Add Integration row.
    var onAddIntegration: () -> Void

    var body: some View {
        List(selection: $selectedProviderID) {
            Section("Filter") {
                Label("All", systemImage: "square.stack.3d.up")
                    .foregroundStyle(.white)
                    .tag(String?.none)

                ForEach(appState.activeProviderIDs, id: \.self) { id in
                    if let provider = ServiceRegistry.shared.provider(withID: id) {
                        providerRow(provider: provider)
                            .tag(String?.some(id))
                    }
                }
            }

            Section("Setup") {
                Button {
                    onAddIntegration()
                } label: {
                    Label("Add Integration", systemImage: "plus")
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)

                Button {
                    onOpenSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(DesignTokens.Palette.background.ignoresSafeArea())
        .navigationTitle("StackLight")
        .preferredColorScheme(.dark)
    }

    private func providerRow(provider: DeploymentProvider) -> some View {
        let theme = ProviderTheme.forProviderID(provider.id)
        return HStack(spacing: 10) {
            Group {
                if let asset = provider.iconAsset {
                    Image(asset)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: provider.iconSymbol)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundStyle(theme.accent)
            .frame(width: 24, height: 24)
            .background(Circle().fill(theme.tint.opacity(0.35)))
            .liquidGlassCircle()

            Text(provider.displayName)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            if appState.errors[provider.id] != nil {
                StatusOrb(status: .failed, size: 8)
                    .frame(width: 14, height: 14)
            }
        }
        .contentShape(Rectangle())
    }
}

#if DEBUG
private struct SidebarPreviewWrapper: View {
    @State private var selected: String? = nil
    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedProviderID: $selected,
                onOpenSettings: {},
                onAddIntegration: {}
            )
        } detail: {
            Text("Detail")
        }
        .environmentObject(AppState())
    }
}

#Preview {
    SidebarPreviewWrapper()
}
#endif
