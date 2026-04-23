import Foundation
import WatchConnectivity

/// iPhone-side `WCSession` owner. Mirrors `AppState`'s latest snapshot onto
/// the paired Apple Watch via two complementary channels:
/// - `updateApplicationContext` — coalesced, latest-wins; the steady stream.
/// - `transferUserInfo` — guaranteed delivery, used only when a deployment
///   status actually changes so the Watch can eagerly reload complications.
///
/// On-demand requests from the Watch (`{"request": "snapshot"}`) are answered
/// with whatever is currently in `SharedStore`. Keeping the phone authoritative
/// and the Watch a pure consumer avoids having to sync tokens to the watch
/// Keychain.
final class PhoneSessionManager: NSObject, WCSessionDelegate {
    static let shared = PhoneSessionManager()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Called by `AppState.publishSnapshot` after `SharedStore.write`. Cheap
    /// and coalesced — safe to call on every poll.
    func push(snapshot: SharedStore.Snapshot) {
        guard isPaired, let payload = encode(snapshot) else { return }
        do {
            try WCSession.default.updateApplicationContext(["snapshot": payload])
        } catch {
            // Context update can fail if we're called before activation; the
            // next successful push will carry the freshest data anyway.
        }
    }

    /// Called only when at least one deployment transitioned status, so the
    /// Watch can reload its complication timelines immediately via the
    /// guaranteed-delivery `transferUserInfo` channel.
    func notifyStatusChange(snapshot: SharedStore.Snapshot) {
        guard isPaired, let payload = encode(snapshot) else { return }
        WCSession.default.transferUserInfo(["snapshot": payload])
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        // On first activation after an update, flush the latest snapshot so the
        // watch doesn't have to wait for the next poll tick to catch up.
        if activationState == .activated, let snapshot = SharedStore.read() {
            push(snapshot: snapshot)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Required when switching between paired watches.
        WCSession.default.activate()
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        if let request = message["request"] as? String, request == "snapshot" {
            if let snapshot = SharedStore.read(), let payload = encode(snapshot) {
                replyHandler(["snapshot": payload])
            } else {
                replyHandler([:])
            }
            return
        }
        replyHandler([:])
    }

    // MARK: - Helpers

    private var isPaired: Bool {
        let session = WCSession.default
        return session.activationState == .activated && session.isPaired && session.isWatchAppInstalled
    }

    private func encode(_ snapshot: SharedStore.Snapshot) -> Data? {
        try? encoder.encode(snapshot)
    }
}
