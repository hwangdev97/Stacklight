import SwiftUI
import StackLightCore
import WidgetKit

/// `.systemSmall` — one deployment, hero treatment.
struct SmallDeploymentView: View {
    let entry: DeploymentEntry

    private var deployment: Deployment? {
        entry.deployments.first
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            if let deployment {
                content(for: deployment)
            } else {
                EmptyStateView()
            }
        }
        .containerBackground(for: .widget) { background }
        .widgetURL(deployment.flatMap(Self.deepLink))
    }

    @ViewBuilder
    private func content(for deployment: Deployment) -> some View {
        let accent = WidgetPalette.providerAccent(for: deployment.providerID)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: WidgetPalette.providerSymbol(for: deployment.providerID))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                Spacer()
                WidgetStatusBadge(status: deployment.status, size: 10)
            }
            Spacer(minLength: 0)
            Text(WidgetFormatters.relativeString(for: deployment.createdAt, now: entry.date))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(deployment.projectName)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(deployment.status.displayName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                if let branch = deployment.branch {
                    Text("·")
                        .foregroundStyle(.white.opacity(0.35))
                    Text(branch)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
    }

    private var background: some View {
        LinearGradient(
            colors: [WidgetPalette.background, WidgetPalette.surface],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func deepLink(for deployment: Deployment) -> URL? {
        URL(string: "stacklight://deployment/\(deployment.providerID)/\(deployment.id)")
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text("No deployments")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text("Open StackLight to configure a provider.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(3)
        }
        .padding(14)
    }
}
