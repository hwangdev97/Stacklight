import SwiftUI
import StackLightCore
import WidgetKit

/// `.systemLarge` — up to 6 deployments with a last-refresh footer.
struct LargeDeploymentView: View {
    let entry: DeploymentEntry

    private var rows: [Deployment] {
        Array(entry.deployments.prefix(6))
    }

    var body: some View {
        ZStack {
            background
            if rows.isEmpty {
                EmptyStateView()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    header
                    VStack(spacing: 6) {
                        ForEach(rows) { deployment in
                            Link(destination: SmallDeploymentView.deepLink(for: deployment)
                                 ?? URL(string: "stacklight://home")!) {
                                DeploymentRow(deployment: deployment, now: entry.date)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    footer
                }
                .padding(14)
            }
        }
        .containerBackground(for: .widget) { background }
    }

    private var header: some View {
        HStack {
            Text("StackLight")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            if entry.activeBuild {
                HStack(spacing: 4) {
                    Circle()
                        .fill(WidgetPalette.building)
                        .frame(width: 6, height: 6)
                    Text("Building")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(.white.opacity(0.08))
                )
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let writtenAt = entry.writtenAt {
            Text("Updated \(WidgetFormatters.relativeString(for: writtenAt, now: entry.date))")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [WidgetPalette.background, WidgetPalette.surface],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
