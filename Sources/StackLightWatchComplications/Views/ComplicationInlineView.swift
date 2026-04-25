import SwiftUI
import WidgetKit

struct ComplicationInlineView: View {
    let entry: WatchDeploymentEntry

    var body: some View {
        Group {
            if let deployment = entry.deployments.first {
                Text("\(deployment.status.emoji) \(deployment.projectName) · \(deployment.status.displayName)")
            } else {
                Text("StackLight · No deployments")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}
