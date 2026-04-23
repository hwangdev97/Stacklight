import UIKit

/// Exists solely to register the `BGTaskScheduler` handler during
/// `application(_:didFinishLaunchingWithOptions:)`. `BGTaskScheduler.register`
/// must run synchronously before the first runloop tick, otherwise iOS
/// crashes the app when it later tries to launch it for a pending task. The
/// SwiftUI `App.init()` runs early enough in practice but isn't guaranteed
/// by Apple; the `UIApplicationDelegateAdaptor` path is the documented one.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackgroundRefreshCoordinator.register()
        PhoneSessionManager.shared.activate()
        return true
    }
}
