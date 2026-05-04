import WidgetKit
import StackLightCore
import SwiftUI

@main
struct StackLightWidgetsBundle: WidgetBundle {
    init() {
        // Mirror the host app so both processes see the same keychain items.
        KeychainManager.accessGroup = "QDJ93ZUQ9B.app.yellowplus.StackLight"
    }

    var body: some Widget {
        DeploymentsWidget()
    }
}
