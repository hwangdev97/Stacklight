import SwiftUI
import StackLightCore
import WidgetKit

/// `.accessoryCircular` — status orb + provider glyph on the lock screen.
struct AccessoryCircularView: View {
    let entry: DeploymentEntry

    var body: some View {
        let deployment = entry.deployments.first
        ZStack {
            AccessoryWidgetBackground()
            if let deployment {
                VStack(spacing: 2) {
                    Image(systemName: WidgetPalette.providerSymbol(for: deployment.providerID))
                        .font(.system(size: 14, weight: .semibold))
                    Circle()
                        .fill(WidgetPalette.statusTint(for: deployment.status))
                        .frame(width: 6, height: 6)
                }
            } else {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 18, weight: .semibold))
            }
        }
        .widgetURL(deployment.flatMap(SmallDeploymentView.deepLink))
        .containerBackground(for: .widget) { Color.clear }
    }
}

/// `.accessoryRectangular` — one line of status detail.
struct AccessoryRectangularView: View {
    let entry: DeploymentEntry

    var body: some View {
        let deployment = entry.deployments.first
        VStack(alignment: .leading, spacing: 1) {
            if let deployment {
                HStack(spacing: 4) {
                    Image(systemName: WidgetPalette.providerSymbol(for: deployment.providerID))
                        .font(.system(size: 11, weight: .semibold))
                    Text(deployment.projectName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                Text("\(deployment.status.displayName) · \(WidgetFormatters.relativeString(for: deployment.createdAt, now: entry.date))")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .lineLimit(1)
            } else {
                Text("StackLight")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text("No deployments")
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .widgetURL(deployment.flatMap(SmallDeploymentView.deepLink))
        .containerBackground(for: .widget) { Color.clear }
    }
}

/// `.accessoryInline` — text-only, used in e.g. the clock complication slot.
struct AccessoryInlineView: View {
    let entry: DeploymentEntry

    var body: some View {
        if let deployment = entry.deployments.first {
            Text("\(deployment.status.emoji) \(deployment.projectName) · \(deployment.status.displayName)")
        } else {
            Text("StackLight · No deployments")
        }
    }
}
