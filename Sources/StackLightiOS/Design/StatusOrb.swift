import SwiftUI
import StackLightCore

/// A small glass orb representing a deployment's status. Replaces the flat
/// `Circle()` status dot used in the original `DeploymentRow`.
///
/// - `.success`   → solid green glass, bright specular
/// - `.failed`    → deep red glass, reduced specular
/// - `.building`  → animated amber pulse with a scaling outer halo
/// - `.queued` / `.cancelled` / `.unknown` → desaturated grey glass
/// - `.reviewing` → blue glass with subtle shimmer
struct StatusOrb: View {
    let status: Deployment.Status
    var size: CGFloat = 18

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tint = ProviderTheme.statusTint(for: status)
        ZStack {
            // Outer halo — pulsed for `.building`, static otherwise.
            TimelineView(.animation(minimumInterval: 1.0/30.0,
                                    paused: reduceMotion || status != .building)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let pulse = status == .building && !reduceMotion
                    ? 0.45 + 0.35 * (0.5 + 0.5 * sin(t * 3.1))
                    : 0.28
                Circle()
                    .fill(tint.opacity(pulse * 0.55))
                    .frame(width: size * (status == .building ? 1.6 : 1.35),
                           height: size * (status == .building ? 1.6 : 1.35))
                    .blur(radius: size * 0.35)
            }
            // The glass sphere itself.
            StatusOrbShaderView(color: tint, pulse: intensity)
                .frame(width: size, height: size)
        }
        .frame(width: size * 1.6, height: size * 1.6)
        .accessibilityLabel(status.displayName)
    }

    private var intensity: CGFloat {
        switch status {
        case .success:   return 0.95
        case .failed:    return 0.70
        case .building:  return 0.90
        case .reviewing: return 0.80
        case .queued, .cancelled, .unknown: return 0.55
        }
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
