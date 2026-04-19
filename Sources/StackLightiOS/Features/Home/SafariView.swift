import SwiftUI
import SafariServices

/// Identifiable wrapper used to drive a `.sheet(item:)` presentation of
/// `SafariView` from an optional URL.
struct SafariTarget: Identifiable {
    let id = UUID()
    let url: URL
}

/// SwiftUI wrapper around `SFSafariViewController` for presenting external
/// URLs in an in-app browser sheet.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
