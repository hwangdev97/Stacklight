import SwiftUI

struct TestFlightGemSmokeBackground: View {
    var cornerRadius: CGFloat = DesignTokens.Radius.md

    var body: some View {
        GlowBackground(
            theme: .forProviderID("testFlight"),
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}
