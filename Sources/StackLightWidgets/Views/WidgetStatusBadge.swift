import SwiftUI
import StackLightCore

/// Widget-safe replacement for the main app's `StatusOrb` — no Metal shader,
/// just a tinted circle with an optional SF Symbol glyph.
struct WidgetStatusBadge: View {
    let status: Deployment.Status
    var size: CGFloat = 12

    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }

    var tint: Color {
        WidgetPalette.statusTint(for: status)
    }
}

enum WidgetPalette {
    static let background = Color(red: 0.04, green: 0.05, blue: 0.08)
    static let surface    = Color(red: 0.09, green: 0.10, blue: 0.13)
    static let hairline   = Color.white.opacity(0.10)

    static let success  = Color(red: 0.27, green: 0.83, blue: 0.55)
    static let failure  = Color(red: 0.98, green: 0.32, blue: 0.36)
    static let building = Color(red: 1.00, green: 0.64, blue: 0.20)
    static let queued   = Color(red: 0.63, green: 0.64, blue: 0.68)
    static let review   = Color(red: 0.33, green: 0.66, blue: 1.00)

    static func statusTint(for status: Deployment.Status) -> Color {
        switch status {
        case .success:   return success
        case .failed:    return failure
        case .building:  return building
        case .queued:    return queued
        case .cancelled: return queued
        case .reviewing: return review
        case .unknown:   return queued
        }
    }

    static func providerAccent(for providerID: String) -> Color {
        switch providerID {
        case "vercel":        return .white
        case "cloudflare":    return Color(red: 1.00, green: 0.55, blue: 0.18)
        case "githubActions": return Color(red: 0.62, green: 0.58, blue: 1.00)
        case "githubPRs":     return Color(red: 0.82, green: 0.56, blue: 1.00)
        case "netlify":       return Color(red: 0.36, green: 0.92, blue: 0.95)
        case "railway":       return Color(red: 0.40, green: 0.96, blue: 0.72)
        case "flyio":         return Color(red: 1.00, green: 0.62, blue: 0.82)
        case "xcodeCloud":    return Color(red: 0.56, green: 0.76, blue: 1.00)
        case "testFlight":    return Color(red: 0.54, green: 0.92, blue: 1.00)
        default:              return Color(red: 0.68, green: 0.72, blue: 0.82)
        }
    }

    static func providerSymbol(for providerID: String) -> String {
        switch providerID {
        case "vercel":        return "triangle.fill"
        case "cloudflare":    return "cloud.fill"
        case "githubActions": return "gearshape.2.fill"
        case "githubPRs":     return "arrow.triangle.pull"
        case "netlify":       return "network"
        case "railway":       return "tram.fill"
        case "flyio":         return "airplane"
        case "xcodeCloud":    return "hammer.fill"
        case "testFlight":    return "paperplane.fill"
        default:              return "square.stack.3d.up"
        }
    }
}

/// Relative date formatter shared across widget views.
enum WidgetFormatters {
    static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    static func relativeString(for date: Date, now: Date = Date()) -> String {
        relative.localizedString(for: date, relativeTo: now)
    }
}
