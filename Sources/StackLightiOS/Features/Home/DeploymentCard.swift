import SwiftUI

/// The hero card for a single deployment — modelled on the large rounded
/// cards in the reference smart-home mockup.
///
/// Layout (approximate):
///
///   ┌──────────────────────────────────────┐
///   │  ○ icon                              │
///   │                                      │
///   │          2m                          │ ← display numeral
///   │      Website                         │ ← project name
///   │                                      │
///   │  [ ● Building · main · abc ]     ⏻  │ ← status chip + power
///   └──────────────────────────────────────┘
///
///  Behind everything: `GlowBackground(theme: providerTheme)` — the animated
///  Metal shader frosted by Liquid Glass.
struct DeploymentCard: View {
    let deployment: Deployment
    var onOpenURL: (URL) -> Void

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var theme: ProviderTheme {
        ProviderTheme.forProviderID(deployment.providerID)
    }

    private var provider: DeploymentProvider? {
        ServiceRegistry.shared.provider(withID: deployment.providerID)
    }

    var body: some View {
        Button {
            if let url = deployment.url { onOpenURL(url) }
        } label: {
            cardBody
        }
        .buttonStyle(HeroCardButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Body

    private var cardBody: some View {
        ZStack(alignment: .topLeading) {
            // Backdrop: shader + glass.
            GlowBackground(
                theme: theme,
                shape: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg,
                                        style: .continuous),
                statusAccent: ProviderTheme.statusTint(for: deployment.status),
                intensity: shaderIntensity,
                animated: true
            )
            // Content chrome.
            VStack(alignment: .leading, spacing: 0) {
                topRow
                Spacer(minLength: DesignTokens.Spacing.sm)
                centerRow
                Spacer(minLength: DesignTokens.Spacing.sm)
                bottomRow
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(height: 172)
        .frame(maxWidth: .infinity)
    }

    // MARK: Content rows

    private var topRow: some View {
        HStack(alignment: .top) {
            if let provider {
                GlassIconChip(provider: provider, tint: theme.accent, size: 36)
            }
            Spacer()
        }
    }

    private var centerRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Self.relativeFormatter.localizedString(
                    for: deployment.createdAt, relativeTo: Date()))
                .font(DesignTokens.Typography.display(size: 46))
                .foregroundStyle(Color.white)
                .monospacedDigit()
                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 2)

            Text(deployment.projectName)
                .font(DesignTokens.Typography.cardTitle)
                .foregroundStyle(Color.white.opacity(0.82))
                .lineLimit(1)
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 1)
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 10) {
            statusChip
            if let branch = deployment.branch {
                branchChip(branch)
            }
            Spacer(minLength: 0)
            if deployment.url != nil {
                powerChip
            }
        }
    }

    // MARK: Chips

    private var statusChip: some View {
        HStack(spacing: 6) {
            StatusOrb(status: deployment.status, size: 10)
                .frame(width: 14, height: 14)
            Text(deployment.status.displayName)
                .font(DesignTokens.Typography.chipLabel)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .liquidGlassChip()
    }

    private func branchChip(_ branch: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 10, weight: .semibold))
            Text(branch)
                .font(DesignTokens.Typography.chipLabel)
                .lineLimit(1)
        }
        .foregroundStyle(Color.white.opacity(0.90))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .liquidGlassChip()
    }

    private var powerChip: some View {
        Image(systemName: "power")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Circle().fill(theme.accent.opacity(0.25)))
            .liquidGlassCircle()
    }

    // MARK: Misc

    private var shaderIntensity: CGFloat {
        switch deployment.status {
        case .building: return 1.1
        case .failed:   return 1.0
        case .success:  return 0.85
        default:        return 0.70
        }
    }

    private var accessibilityText: String {
        let providerName = provider?.displayName ?? deployment.providerID
        return "\(providerName) \(deployment.projectName), \(deployment.status.displayName), " +
               Self.relativeFormatter.localizedString(for: deployment.createdAt, relativeTo: Date())
    }
}

/// Gentle press feedback — scales & dims slightly so tapping feels alive.
private struct HeroCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.75),
                       value: configuration.isPressed)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            DeploymentCard(deployment: Deployment(
                id: "1",
                providerID: "vercel",
                projectName: "marketing-site",
                status: .success,
                url: URL(string: "https://vercel.com"),
                createdAt: Date().addingTimeInterval(-120),
                commitMessage: "Update landing copy",
                branch: "main"
            )) { _ in }

            DeploymentCard(deployment: Deployment(
                id: "2",
                providerID: "cloudflare",
                projectName: "docs",
                status: .building,
                url: URL(string: "https://cloudflare.com"),
                createdAt: Date().addingTimeInterval(-30),
                commitMessage: "Rework nav",
                branch: "feat/nav"
            )) { _ in }

            DeploymentCard(deployment: Deployment(
                id: "3",
                providerID: "netlify",
                projectName: "blog",
                status: .failed,
                url: nil,
                createdAt: Date().addingTimeInterval(-900),
                commitMessage: "Fix broken build",
                branch: "fix/build"
            )) { _ in }
        }
        .padding()
    }
    .background(DesignTokens.Palette.background)
    .preferredColorScheme(.dark)
}
