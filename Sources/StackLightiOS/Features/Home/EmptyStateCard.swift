import SwiftUI

/// Card shown on the Home screen when there's nothing to display.
struct EmptyStateCard: View {
    let title: String
    let message: String
    let cta: String?
    let systemImage: String
    var action: (() -> Void)? = nil

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
                theme: .neutral,
                shape: RoundedRectangle(cornerRadius: DesignTokens.Radius.hero,
                                        style: .continuous),
                intensity: 0.9)
        )
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
