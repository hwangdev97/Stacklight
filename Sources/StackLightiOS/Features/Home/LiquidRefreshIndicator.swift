import SwiftUI

/// A custom pull-to-refresh indicator driven by the `liquidDroplet` Metal
/// shader. As the user drags, the droplet stretches; when it releases or
/// refreshing completes, it snaps back and fades out.
struct LiquidRefreshIndicator: View {
    /// 0.0 = at rest, 1.0 = fully pulled / refreshing.
    let progress: CGFloat
    let isRefreshing: Bool
    var tint: Color = DesignTokens.Palette.review

    private var stretch: CGFloat {
        isRefreshing ? 1.35 + 0.25 * sin(Date().timeIntervalSinceReferenceDate * 3.2)
                     : 1.0 + progress * 1.4
    }

    private var opacity: CGFloat {
        isRefreshing ? 1.0 : max(progress, 0.0)
    }

    var body: some View {
        LiquidDropletShaderView(color: tint,
                                stretch: stretch,
                                intensity: opacity)
            .frame(width: 44, height: 44)
            .scaleEffect(isRefreshing ? 1.1 : (0.7 + progress * 0.45))
            .animation(.spring(response: 0.35, dampingFraction: 0.72),
                       value: isRefreshing)
            .accessibilityHidden(true)
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
