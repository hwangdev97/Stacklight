import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.md) {
                        SettingsCard(title: "General") {
                            NavigationLink {
                                GeneralSettingsView()
                            } label: {
                                linkRow(icon: "gear", title: "General",
                                        tint: .white)
                            }
                            .buttonStyle(.plain)
                        }

                        SettingsCard(title: "Services") {
                            VStack(spacing: 2) {
                                ForEach(Array(ServiceRegistry.shared.providers.enumerated()),
                                        id: \.element.id) { idx, provider in
                                    NavigationLink {
                                        ProviderSettingsView(provider: provider)
                                            .environmentObject(appState)
                                    } label: {
                                        ProviderRow(provider: provider,
                                                    error: appState.errors[provider.id])
                                    }
                                    .buttonStyle(.plain)

                                    if idx < ServiceRegistry.shared.providers.count - 1 {
                                        Divider().overlay(DesignTokens.Palette.hairline)
                                            .padding(.leading, 54)
                                    }
                                }
                            }
                        }

                        SettingsCard(title: "About") {
                            VStack(spacing: 2) {
                                row(title: "Version", value: appVersion)
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
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.xxl)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }

    // MARK: Rows

    private func linkRow(icon: String, title: String, tint: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(tint.opacity(0.85))
                .frame(width: 22)
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.vertical, 8)
    }

    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.vertical, 8)
    }

    private var appVersion: String {
        let v = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"
        let b = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?"
        return "\(v) (\(b))"
    }
}

private struct ProviderRow: View {
    let provider: DeploymentProvider
    let error: String?

    private var theme: ProviderTheme { ProviderTheme.forProviderID(provider.id) }

    var body: some View {
        HStack(spacing: 12) {
            // Provider icon with a faint brand-tinted glass halo.
            Group {
                if let asset = provider.iconAsset {
                    Image(asset)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: provider.iconSymbol)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundStyle(theme.accent)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(theme.tint.opacity(0.45))
            )
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

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.vertical, 6)
    }
}
