import Foundation
import WatchConnectivity
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Owns the `WCSession` on the Watch. Receives snapshots from the paired iPhone
/// through two channels:
/// - `applicationContext` — latest-wins, coalesced by iOS, used for the steady
///   state stream.
/// - `userInfo` — guaranteed delivery, used by the iPhone only when a status
///   actually changes so we can eagerly reload complications.
///
/// On receipt we decode a `SharedStore.Snapshot`, write it to the Watch's App
/// Group container, and poke the complication timeline + UI.
final class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    /// Posted on the main queue after a new snapshot lands in `SharedStore`.
    static let snapshotDidChange = Notification.Name("StackLight.WatchSessionManager.snapshotDidChange")

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Ask the iPhone for the freshest snapshot it has. The reply handler runs
    /// on WatchConnectivity's private queue; callers should hop to the main
    /// actor if they touch UI.
    func requestSnapshot(completion: @escaping (Bool) -> Void) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            completion(false)
            return
        }
        session.sendMessage(["request": "snapshot"]) { [weak self] reply in
            self?.handleReplyOrMessage(reply)
            completion(true)
        } errorHandler: { _ in
            completion(false)
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        // No-op. iOS-side activation callbacks are handled on the phone.
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        handleReplyOrMessage(applicationContext)
    }

    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleReplyOrMessage(userInfo)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        handleReplyOrMessage(message)
    }

    // MARK: - Decoding

    private func handleReplyOrMessage(_ payload: [String: Any]) {
        guard let data = payload["snapshot"] as? Data,
              let snapshot = try? decoder.decode(SharedStore.Snapshot.self, from: data) else {
            return
        }
        SharedStore.write(snapshot)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        NotificationCenter.default.post(name: Self.snapshotDidChange, object: nil)
    }
}
