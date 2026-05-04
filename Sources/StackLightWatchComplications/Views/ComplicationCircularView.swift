import SwiftUI
import StackLightCore
import WidgetKit

struct ComplicationCircularView: View {
    let entry: WatchDeploymentEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.deployments.isEmpty {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 2) {
                    Image(systemName: symbol(for: entry.rollupStatus))
                        .font(.system(size: 14, weight: .bold))
                    Text("\(entry.deployments.count)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
            }
        }
        .widgetAccentable()
        .containerBackground(for: .widget) { Color.clear }
    }

    private func symbol(for status: Deployment.Status) -> String {
        switch status {
        case .success:   return "checkmark"
        case .failed:    return "xmark"
        case .building:  return "arrow.triangle.2.circlepath"
        case .queued:    return "clock"
        case .reviewing: return "eye"
        case .cancelled: return "slash.circle"
        case .unknown:   return "questionmark"
        }
    }
}
