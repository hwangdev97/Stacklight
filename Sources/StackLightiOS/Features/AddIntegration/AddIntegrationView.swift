import SwiftUI
import StackLightCore

/// Modal picker for adding a new integration. Redesigned as a 2-column grid
/// of glass tiles, each showing a live shader preview of the provider's
/// visual signature.
struct AddIntegrationView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProviderID: String?

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
                            Button {
                                selectedProviderID = provider.id
                            } label: {
                                ProviderTile(provider: provider)
                            }
                            .buttonStyle(.plain)
                            .focusEffectDisabled()
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
            .navigationDestination(isPresented: settingsDestinationBinding) {
                if let provider = selectedProvider {
                    ProviderSettingsView(provider: provider, dismissOnSave: true)
                        .environmentObject(appState)
                }
            }
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

    private var selectedProvider: DeploymentProvider? {
        guard let selectedProviderID else { return nil }
        return ServiceRegistry.shared.provider(withID: selectedProviderID)
    }

    private var settingsDestinationBinding: Binding<Bool> {
        Binding(
            get: { selectedProviderID != nil },
            set: { isPresented in
                if !isPresented { selectedProviderID = nil }
            }
        )
    }
}

/// A single provider tile — glass card with live shader preview.
private struct ProviderTile: View {
    let provider: DeploymentProvider

    private var theme: ProviderTheme { ProviderTheme.forProviderID(provider.id) }

    var body: some View {
        ZStack {
            if provider.id == "vercel" {
                VercelHeatmapTileBackground()
            } else if provider.id == "cloudflare" {
                CloudflareGrainGradientBackground()
            } else if provider.id == "netlify" {
                NetlifyNeuroNoiseBackground()
            } else if provider.id == "railway" {
                RailwaySimplexNoiseBackground()
            } else if provider.id == "flyio" {
                FlyIOMeshGradientBackground()
            } else if provider.id == "xcodeCloud" {
                XcodeCloudGodRaysBackground()
            } else if provider.id == "testFlight" {
                TestFlightGemSmokeBackground()
            } else if provider.id == "githubActions" {
                GitHubActionsDitheringBackground()
            } else if provider.id == "githubPRs" {
                GitHubPullRequestDitheringBackground()
            } else {
                GlowBackground(
                    theme: theme,
                    shape: RoundedRectangle(cornerRadius: DesignTokens.Radius.md,
                                            style: .continuous),
                    intensity: 0.9)
            }

            VStack(alignment: .leading, spacing: 0) {
                // Top area: floating icon chip
                HStack {
                    GlassIconChip(provider: provider,
                                  tint: iconTint,
                                  size: 34)
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
        }
        .frame(height: 130)
        .frame(maxWidth: .infinity)
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

    private var iconTint: Color {
        ["cloudflare", "githubActions", "githubPRs", "netlify", "railway", "zeabur", "flyio", "xcodeCloud", "testFlight"].contains(provider.id) ? .white : theme.accent
    }

    private var subtitle: String {
        switch provider.id {
        case "vercel":        return "Deployments"
        case "cloudflare":    return "Pages deployments"
        case "githubActions": return "Workflow runs"
        case "githubPRs":     return "Open pull requests"
        case "netlify":       return "Deployments"
        case "railway":       return "Deployments"
        case "supabase":      return "Project health & branches"
        case "zeabur":        return "Deployments"
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
