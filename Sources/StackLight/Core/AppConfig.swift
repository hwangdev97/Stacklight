import Foundation

/// Cross-process `UserDefaults` accessor. On iOS the host app and the widget
/// extension share the `group.app.yellowplus.StackLight` App Group, so both
/// processes see the same provider settings. On macOS the App Group isn't
/// configured; we fall back to `.standard`, which preserves existing behavior
/// for the menu-bar app.
enum AppConfig {
    static let appGroupSuite = SharedStore.suiteName

    static var defaults: UserDefaults {
        #if os(iOS) || os(watchOS)
        return UserDefaults(suiteName: appGroupSuite) ?? .standard
        #else
        return .standard
        #endif
    }
}
