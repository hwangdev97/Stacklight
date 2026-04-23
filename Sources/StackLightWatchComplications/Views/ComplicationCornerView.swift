import SwiftUI
import WidgetKit

/// `.accessoryCorner` — pinned to a watch-face corner with a curved text
/// label and a center glyph. We reflect the rolled-up status in the glyph
/// and show the most recent project name along the curve.
struct ComplicationCornerView: View {
    let entry: WatchDeploymentEntry

    var body: some View {
        Image(systemName: glyph)
            .font(.system(size: 18, weight: .bold))
            .widgetLabel {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .widgetAccentable()
            .containerBackground(for: .widget) { Color.clear }
    }

    private var glyph: String {
        switch entry.rollupStatus {
        case .success:   return "checkmark.circle.fill"
        case .failed:    return "xmark.circle.fill"
        case .building:  return "arrow.triangle.2.circlepath"
        case .queued:    return "clock.fill"
        case .reviewing: return "eye.fill"
        case .cancelled: return "slash.circle.fill"
        case .unknown:   return "square.stack.3d.up"
        }
    }

    private var label: String {
        guard let top = entry.deployments.first else {
            return "StackLight"
        }
        return "\(top.projectName) · \(top.status.displayName)"
    }
}
