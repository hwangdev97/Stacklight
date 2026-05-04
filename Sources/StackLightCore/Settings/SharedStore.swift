import Foundation

/// Cross-process snapshot shared between the iOS app and its widget extension
/// via the `group.app.yellowplus.StackLight` App Group. The macOS target can
/// also link this file; on macOS the App Group UserDefaults just falls back to
/// an in-process suite and nothing reads from it, so it is a no-op.
public enum SharedStore {
    public static let suiteName = "group.app.yellowplus.StackLight"
    public static let snapshotKey = "deployments.snapshot.v1"
    public static let schemaVersion = 1

    public struct Snapshot: Codable {
        public var deployments: [Deployment]
        public var writtenAt: Date
        public var activeBuild: Bool
        public var schemaVersion: Int

        public init(deployments: [Deployment], writtenAt: Date = Date()) {
            self.deployments = deployments
            self.writtenAt = writtenAt
            self.activeBuild = deployments.contains {
                $0.status == .building || $0.status == .queued
            }
            self.schemaVersion = SharedStore.schemaVersion
        }
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    public static func write(_ snapshot: Snapshot) {
        guard let defaults else { return }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            defaults.set(data, forKey: snapshotKey)
        } catch {
            // Swallow — a failed snapshot write shouldn't crash the app.
        }
    }

    public static func write(deployments: [Deployment]) {
        write(Snapshot(deployments: deployments))
    }

    public static func read() -> Snapshot? {
        guard let defaults, let data = defaults.data(forKey: snapshotKey) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Snapshot.self, from: data)
    }

    public static func clear() {
        defaults?.removeObject(forKey: snapshotKey)
    }
}
