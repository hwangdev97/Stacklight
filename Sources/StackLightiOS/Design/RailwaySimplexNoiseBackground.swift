import SwiftUI

struct RailwaySimplexNoiseBackground: View {
    var cornerRadius: CGFloat = DesignTokens.Radius.md

    var body: some View {
        GlowBackground(
            theme: .forProviderID("railway"),
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}
