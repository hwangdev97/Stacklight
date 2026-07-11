import SwiftUI
import StackLightCore

/// A lightweight status indicator that never starts a display-linked timeline.
struct StatusOrb: View {
    let status: Deployment.Status
    var size: CGFloat = 18

    var body: some View {
        let tint = ProviderTheme.statusTint(for: status)
        ZStack {
            Circle()
                .fill(tint.opacity(status == .building ? 0.24 : 0.14))
                .frame(width: size * 1.45, height: size * 1.45)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.5))
        }
        .frame(width: size * 1.6, height: size * 1.6)
        .accessibilityLabel(status.displayName)
    }
}

#Preview {
    HStack(spacing: 18) {
        StatusOrb(status: .success)
        StatusOrb(status: .failed)
        StatusOrb(status: .building)
        StatusOrb(status: .queued)
        StatusOrb(status: .reviewing)
    }
    .padding(40)
    .background(DesignTokens.Palette.background)
}
