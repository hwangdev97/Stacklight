import Foundation

struct Deployment: Identifiable {
    let id: String
    let providerID: String
    let projectName: String
    let status: Status
    let url: URL?
    let createdAt: Date
    let commitMessage: String?
    let branch: String?

    enum Status: String {
        case building
        case success
        case failed
        case cancelled
        case queued
        case reviewing // TestFlight review
        case unknown

        var emoji: String {
            switch self {
            case .building:  return "◐"
            case .success:   return "●"
            case .failed:    return "✕"
            case .cancelled: return "○"
            case .queued:    return "◌"
            case .reviewing: return "◉"
            case .unknown:   return "?"
            }
        }

        var displayName: String {
            switch self {
            case .building:  return "Building"
            case .success:   return "Ready"
            case .failed:    return "Failed"
            case .cancelled: return "Cancelled"
            case .queued:    return "Queued"
            case .reviewing: return "In Review"
            case .unknown:   return "Unknown"
            }
        }
    }
}

extension Deployment {
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

/// Per-fetch result for a single provider. `deployments` holds everything that
/// was fetched successfully; `itemErrors` collects per-entry failures so one
/// bad repo/site/app ID doesn't poison the whole batch.
struct DeploymentFetchResult {
    let deployments: [Deployment]
    /// Ordered list of `(entry-identifier, error)`. The identifier is whatever
    /// the provider shows the user for that entry — e.g. `"owner/repo"` for
    /// GitHub, `"12345"` for a TestFlight App ID.
    let itemErrors: [(item: String, error: Error)]

    static let empty = DeploymentFetchResult(deployments: [], itemErrors: [])

    init(deployments: [Deployment], itemErrors: [(item: String, error: Error)] = []) {
        self.deployments = deployments
        self.itemErrors = itemErrors
    }
}
