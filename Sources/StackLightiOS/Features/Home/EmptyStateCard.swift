import SwiftUI

/// Glass card shown on the Home screen when there's nothing to display
/// (no integrations configured, or all configured integrations are idle).
/// The backdrop rotates through a handful of provider themes every few
/// seconds so the empty state still feels alive and previews the app's
/// aesthetic once configured.
struct EmptyStateCard: View {
    let title: String
    let message: String
    let cta: String?
    let systemImage: String
    var action: (() -> Void)? = nil

    @State private var themeIndex = 0
    private static let rotatingThemes: [ProviderTheme] = [
        .forProviderID("vercel"),
        .forProviderID("cloudflare"),
        .forProviderID("netlify"),
        .forProviderID("flyio"),
        .forProviderID("xcodeCloud"),
    ]

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            GlassIconChip(systemImage: systemImage, tint: .white, size: 56)

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(.white)
                Text(message)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.80))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let cta, let action {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: systemImage)
                        Text(cta).fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .liquidGlassChip()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 48)
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            GlowBackground(
                theme: Self.rotatingThemes[themeIndex],
                shape: RoundedRectangle(cornerRadius: DesignTokens.Radius.hero,
                                        style: .continuous),
                intensity: 0.9)
            .animation(.easeInOut(duration: 1.5), value: themeIndex)
        )
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                withAnimation { themeIndex = (themeIndex + 1) % Self.rotatingThemes.count }
            }
        }
    }
}

#Preview("No Integrations") {
    EmptyStateCard(
        title: "No Integrations",
        message: "Add an integration to start monitoring deployments.",
        cta: "Add Integration",
        systemImage: "plus"
    ) {}
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DesignTokens.Palette.background)
    .preferredColorScheme(.dark)
}

#Preview("All Quiet") {
    EmptyStateCard(
        title: "All Quiet",
        message: "No recent deployments. Pull down to refresh.",
        cta: nil,
        systemImage: "clock"
    )
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DesignTokens.Palette.background)
    .preferredColorScheme(.dark)
}
