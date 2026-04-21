import SwiftUI

/// A provider's visual "signature" — the tint that drives its shader backdrop,
/// the brighter accent used for the floating power/status chips, and the outer
/// glow used in the Liquid Glass border. Each of the 9 deployment providers
/// gets a distinct triad so the cards are recognisable at a glance.
struct ProviderTheme: Equatable {
    /// Which parameterised shader kernel to use (see `Providers.metal`).
    enum ShaderKind: Int32 {
        case monoBeam      = 0  // Vercel
        case softBlobs     = 1  // Cloudflare
        case gearShimmer   = 2  // GitHub Actions
        case diffStreaks   = 3  // GitHub PRs
        case rippleField   = 4  // Netlify
        case motionStreaks = 5  // Railway
        case vaporTrail    = 6  // Fly.io
        case depthClouds   = 7  // Xcode Cloud
        case sweepWing     = 8  // TestFlight
        case errorAura     = 9  // Error banner
        case neutral       = 10 // Fallback / empty state cycle
        case pixelBeams    = 11 // Cloudflare (pixel-beam variant)
    }

    let tint:   Color
    let accent: Color
    let glow:   Color
    let shader: ShaderKind

    /// Provider resolution from the shared `DeploymentProvider.id`.
    static func forProviderID(_ id: String) -> ProviderTheme {
        switch id {
        case "vercel":
            return .init(
                tint:   Color(red: 0.08, green: 0.09, blue: 0.12),
                accent: .white,
                glow:   Color.white.opacity(0.55),
                shader: .monoBeam)
        case "cloudflare":
            return .init(
                tint:   Color(red: 0.98, green: 0.48, blue: 0.12),
                accent: Color(red: 1.00, green: 0.78, blue: 0.32),
                glow:   Color(red: 1.00, green: 0.55, blue: 0.18).opacity(0.80),
                shader: .pixelBeams)
        case "githubActions":
            return .init(
                tint:   Color(red: 0.36, green: 0.33, blue: 0.86),
                accent: Color(red: 0.62, green: 0.58, blue: 1.00),
                glow:   Color(red: 0.44, green: 0.40, blue: 0.96).opacity(0.75),
                shader: .gearShimmer)
        case "githubPRs":
            return .init(
                tint:   Color(red: 0.52, green: 0.28, blue: 0.85),
                accent: Color(red: 0.82, green: 0.56, blue: 1.00),
                glow:   Color(red: 0.64, green: 0.34, blue: 0.95).opacity(0.75),
                shader: .diffStreaks)
        case "netlify":
            return .init(
                tint:   Color(red: 0.09, green: 0.64, blue: 0.70),
                accent: Color(red: 0.36, green: 0.92, blue: 0.95),
                glow:   Color(red: 0.18, green: 0.80, blue: 0.83).opacity(0.75),
                shader: .rippleField)
        case "railway":
            return .init(
                tint:   Color(red: 0.11, green: 0.58, blue: 0.44),
                accent: Color(red: 0.40, green: 0.96, blue: 0.72),
                glow:   Color(red: 0.22, green: 0.84, blue: 0.58).opacity(0.75),
                shader: .motionStreaks)
        case "flyio":
            return .init(
                tint:   Color(red: 0.92, green: 0.28, blue: 0.60),
                accent: Color(red: 1.00, green: 0.62, blue: 0.82),
                glow:   Color(red: 0.98, green: 0.40, blue: 0.70).opacity(0.80),
                shader: .vaporTrail)
        case "xcodeCloud":
            return .init(
                tint:   Color(red: 0.14, green: 0.40, blue: 0.96),
                accent: Color(red: 0.56, green: 0.76, blue: 1.00),
                glow:   Color(red: 0.28, green: 0.55, blue: 1.00).opacity(0.80),
                shader: .depthClouds)
        case "testFlight":
            return .init(
                tint:   Color(red: 0.16, green: 0.70, blue: 0.92),
                accent: Color(red: 0.54, green: 0.92, blue: 1.00),
                glow:   Color(red: 0.28, green: 0.82, blue: 0.98).opacity(0.78),
                shader: .sweepWing)
        default:
            return .neutral
        }
    }

    // Convenience specials
    static let neutral = ProviderTheme(
        tint:   Color(red: 0.25, green: 0.27, blue: 0.33),
        accent: Color(red: 0.68, green: 0.72, blue: 0.82),
        glow:   Color.white.opacity(0.35),
        shader: .neutral)

    static let error = ProviderTheme(
        tint:   Color(red: 0.82, green: 0.20, blue: 0.26),
        accent: Color(red: 1.00, green: 0.54, blue: 0.48),
        glow:   Color(red: 1.00, green: 0.30, blue: 0.32).opacity(0.80),
        shader: .errorAura)

    /// The tint used for a status chip inside the card (e.g. green for success).
    static func statusTint(for status: Deployment.Status) -> Color {
        switch status {
        case .success:   return DesignTokens.Palette.success
        case .failed:    return DesignTokens.Palette.failure
        case .building:  return DesignTokens.Palette.building
        case .queued:    return DesignTokens.Palette.queued
        case .cancelled: return DesignTokens.Palette.queued
        case .reviewing: return DesignTokens.Palette.review
        case .unknown:   return DesignTokens.Palette.queued
        }
    }
}
