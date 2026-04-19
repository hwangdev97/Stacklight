import SwiftUI

/// Small glass pill shown at the bottom of the Home deployment list,
/// indicating how long ago the data was refreshed. The leading dot shifts
/// colour as the data ages — green / amber / grey.
struct LastRefreshPill: View {
    let lastRefresh: Date

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var staleness: Color {
        let age = -lastRefresh.timeIntervalSinceNow
        switch age {
        case ..<120:  return DesignTokens.Palette.success
        case ..<600:  return DesignTokens.Palette.building
        default:      return DesignTokens.Palette.queued
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(staleness)
                .frame(width: 6, height: 6)
                .shadow(color: staleness, radius: 4)
            Text("Updated \(Self.relativeFormatter.localizedString(for: lastRefresh, relativeTo: Date()))")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .liquidGlassChip()
    }
}

#Preview {
    VStack(spacing: 20) {
        LastRefreshPill(lastRefresh: Date().addingTimeInterval(-30))
        LastRefreshPill(lastRefresh: Date().addingTimeInterval(-300))
        LastRefreshPill(lastRefresh: Date().addingTimeInterval(-3600))
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DesignTokens.Palette.background)
    .preferredColorScheme(.dark)
}
