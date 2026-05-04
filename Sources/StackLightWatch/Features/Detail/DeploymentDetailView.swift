import SwiftUI
import StackLightCore

struct DeploymentDetailView: View {
    let deployment: Deployment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header
                Divider()
                metaRow(label: "Status", value: deployment.status.displayName)
                if let branch = deployment.branch {
                    metaRow(label: "Branch", value: branch)
                }
                if let message = deployment.commitMessage, !message.isEmpty {
                    metaRow(label: "Commit", value: message, multiline: true)
                }
                metaRow(label: "When", value: deployment.relativeTime)

                if let url = deployment.url {
                    Label("Open on iPhone", systemImage: "iphone.and.arrow.forward")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.top, 4)
                        .accessibilityHint("Opens \(url.absoluteString) on your iPhone")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .navigationTitle(deployment.projectName)
        .userActivity(
            "app.yellowplus.StackLight.openDeployment",
            isActive: deployment.url != nil
        ) { activity in
            guard let url = deployment.url else { return }
            activity.isEligibleForHandoff = true
            activity.webpageURL = url
            activity.userInfo = ["url": url.absoluteString]
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: WidgetPalette.providerSymbol(for: deployment.providerID))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WidgetPalette.providerAccent(for: deployment.providerID))
            Text(deployment.projectName)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Spacer()
            WidgetStatusBadge(status: deployment.status, size: 10)
        }
    }

    private func metaRow(label: String, value: String, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .lineLimit(multiline ? nil : 1)
                .fixedSize(horizontal: false, vertical: multiline)
        }
    }
}

