import SwiftUI

/// iPad-style Settings: sidebar + detail inside the settings sheet. Compact
/// layouts keep using the existing `SettingsView` (nested `NavigationStack`).
struct SettingsSplitView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selection: SettingsDestination? = .general
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SettingsSidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
                .navigationTitle("Settings")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .liquidGlassChip()
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.highlight)
                    }
                }
        } detail: {
            NavigationStack {
                SettingsDetail(selection: selection)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(.dark)
        .tint(.white)
    }
}

// MARK: - Destination

enum SettingsDestination: Hashable {
    case general
    case about
    case provider(String)
}

// MARK: - Sidebar

struct SettingsSidebar: View {
    @EnvironmentObject var appState: AppState
    @Binding var selection: SettingsDestination?

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("General", systemImage: "gear")
                    .foregroundStyle(.white)
                    .tag(SettingsDestination.general)
            }

            Section("Services") {
                ForEach(ServiceRegistry.shared.providers, id: \.id) { provider in
                    SidebarProviderRow(
                        provider: provider,
                        error: appState.errors[provider.id]
                    )
                    .tag(SettingsDestination.provider(provider.id))
                }
            }

            Section {
                Label("About", systemImage: "info.circle")
                    .foregroundStyle(.white)
                    .tag(SettingsDestination.about)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(DesignTokens.Palette.background.ignoresSafeArea())
    }
}

private struct SidebarProviderRow: View {
    let provider: DeploymentProvider
    let error: String?

    private var theme: ProviderTheme { ProviderTheme.forProviderID(provider.id) }

    var body: some View {
        HStack(spacing: 10) {
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

            if !provider.isConfigured {
                Text("Not set up")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.white.opacity(0.45))
            } else if error != nil {
                StatusOrb(status: .failed, size: 8)
                    .frame(width: 14, height: 14)
            } else {
                StatusOrb(status: .success, size: 8)
                    .frame(width: 14, height: 14)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Detail

private struct SettingsDetail: View {
    @EnvironmentObject var appState: AppState
    let selection: SettingsDestination?

    var body: some View {
        Group {
            switch selection {
            case .general:
                GeneralSettingsView()
            case .about:
                AboutView()
            case .provider(let id):
                if let provider = ServiceRegistry.shared.provider(withID: id) {
                    ProviderSettingsView(provider: provider)
                } else {
                    placeholder
                }
            case nil:
                placeholder
            }
        }
        .background(DesignTokens.Palette.background.ignoresSafeArea())
    }

    private var placeholder: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
            Text("Select an item")
                .font(DesignTokens.Typography.cardTitle)
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Palette.background.ignoresSafeArea())
    }
}

// MARK: - About

private struct AboutView: View {
    private var appVersion: String {
        let v = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"
        let b = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?"
        return "\(v) (\(b))"
    }

    var body: some View {
        ZStack {
            DesignTokens.Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.md) {
                    SettingsCard(title: "About") {
                        VStack(spacing: 2) {
                            HStack {
                                Text("Version")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(appVersion)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.vertical, 8)

                            Divider().overlay(DesignTokens.Palette.hairline)

                            Link(destination: URL(string: "https://github.com/hwangdev97/stacklight")!) {
                                HStack {
                                    Image(systemName: "link")
                                        .foregroundStyle(.white.opacity(0.75))
                                        .frame(width: 22)
                                    Text("GitHub")
                                        .foregroundStyle(.white)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

#if DEBUG
#Preview {
    SettingsSplitView()
        .environmentObject(AppState())
}
#endif
