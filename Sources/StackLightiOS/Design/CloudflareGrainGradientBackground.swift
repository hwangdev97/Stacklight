import SwiftUI

struct CloudflareGrainGradientBackground: View {
    var cornerRadius: CGFloat = DesignTokens.Radius.md

    var body: some View {
        GlowBackground(
            theme: .forProviderID("cloudflare"),
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}
