import Foundation
import SwiftUI
import StackLightCore

struct CalendarEvent: Identifiable {
    let deployment: Deployment
    let provider: DeploymentProvider?

    var id: String { deployment.id }
    var title: String { deployment.projectName }
    var subtitle: String? { deployment.commitMessage }
    var startsAt: Date { deployment.createdAt }
    var status: Deployment.Status { deployment.status }
    var url: URL? { deployment.url }
    var branch: String? { deployment.branch }
    var providerLabel: String { provider?.displayName ?? deployment.providerID }
    var providerColor: Color { provider?.color ?? .accentColor }
    var repository: String? { deployment.repository }
}
