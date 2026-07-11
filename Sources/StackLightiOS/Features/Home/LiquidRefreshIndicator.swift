import SwiftUI

/// A lightweight pull-to-refresh indicator.
struct LiquidRefreshIndicator: View {
    /// 0.0 = at rest, 1.0 = fully pulled / refreshing.
    let progress: CGFloat
    let isRefreshing: Bool
    var tint: Color = DesignTokens.Palette.review

    @ViewBuilder
    var body: some View {
        if isRefreshing {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(tint)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
        } else {
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 24, height: 24)
                .opacity(max(progress, 0))
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        LiquidRefreshIndicator(progress: 0.0, isRefreshing: false)
        LiquidRefreshIndicator(progress: 0.5, isRefreshing: false)
        LiquidRefreshIndicator(progress: 1.0, isRefreshing: false)
        LiquidRefreshIndicator(progress: 1.0, isRefreshing: true)
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DesignTokens.Palette.background)
    .preferredColorScheme(.dark)
}
