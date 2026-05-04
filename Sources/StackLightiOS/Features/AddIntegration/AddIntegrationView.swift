import SwiftUI
import StackLightCore

/// Modal picker for adding a new integration. Redesigned as a 2-column grid
/// of glass tiles, each showing a live shader preview of the provider's
/// visual signature.
struct AddIntegrationView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Palette.background.ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(ServiceRegistry.shared.providers, id: \.id) { provider in
                            NavigationLink {
                                ProviderSettingsView(provider: provider, dismissOnSave: true)
                                    .environmentObject(appState)
                            } label: {
                                ProviderTile(provider: provider)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(DesignTokens.Spacing.lg)

                    Text("Credentials are stored securely in the iOS Keychain.")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                        .padding(.bottom, DesignTokens.Spacing.xl)
                }
            }
            .navigationTitle("Add Integration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
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
}

/// A single provider tile — glass card with live shader preview.
private struct ProviderTile: View {
    let provider: DeploymentProvider

    private var theme: ProviderTheme { ProviderTheme.forProviderID(provider.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top area: floating icon chip
            HStack {
                GlassIconChip(provider: provider,
                              tint: theme.accent, size: 34)
                Spacer()
                if provider.isConfigured {
                    connectedBadge
                }
            }
            Spacer(minLength: 16)

            // Text block
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(DesignTokens.Typography.cardTitle)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(height: 130)
        .frame(maxWidth: .infinity)
        .background(
            GlowBackground(
                theme: theme,
                shape: RoundedRectangle(cornerRadius: DesignTokens.Radius.md,
                                        style: .continuous),
                intensity: 0.9)
        )
    }

    private var connectedBadge: some View {
        HStack(spacing: 4) {
            StatusOrb(status: .success, size: 8)
                .frame(width: 12, height: 12)
            Text("Connected")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .liquidGlassChip()
    }

    private var subtitle: String {
        switch provider.id {
        case "vercel":        return "Deployments"
        case "cloudflare":    return "Pages deployments"
        case "githubActions": return "Workflow runs"
        case "githubPRs":     return "Open pull requests"
        case "netlify":       return "Deployments"
        case "railway":       return "Deployments"
        case "flyio":         return "Machine deployments"
        case "xcodeCloud":    return "Build results"
        case "testFlight":    return "Build processing & review"
        default:              return "Integration"
        }
    }
}

#Preview {
    AddIntegrationView()
        .environmentObject(AppState())
}
