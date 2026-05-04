import Foundation

public struct Deployment: Identifiable {
    public let id: String
    public let providerID: String
    public let projectName: String
    /// Optional repository identifier shown alongside the project name.
    /// Used by GitHub Actions to disambiguate which configured repo a row
    /// belongs to when multiple repos are being watched.
    public let repository: String?
    public let status: Status
    public let url: URL?
    public let createdAt: Date
    public let commitMessage: String?
    public let branch: String?

    public init(
        id: String,
        providerID: String,
        projectName: String,
        repository: String? = nil,
        status: Status,
        url: URL?,
        createdAt: Date,
        commitMessage: String?,
        branch: String?
    ) {
        self.id = id
        self.providerID = providerID
        self.projectName = projectName
        self.repository = repository
        self.status = status
        self.url = url
        self.createdAt = createdAt
        self.commitMessage = commitMessage
        self.branch = branch
    }

    public enum Status: String {
        case building
        case success
        case failed
        case cancelled
        case queued
        case reviewing // TestFlight review
        case unknown

        public var emoji: String {
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

        public var displayName: String {
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
    public var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

/// Per-fetch result for a single provider. `deployments` holds everything that
/// was fetched successfully; `itemErrors` collects per-entry failures so one
/// bad repo/site/app ID doesn't poison the whole batch.
public struct DeploymentFetchResult {
    public let deployments: [Deployment]
    /// Ordered list of `(entry-identifier, error)`. The identifier is whatever
    /// the provider shows the user for that entry — e.g. `"owner/repo"` for
    /// GitHub, `"12345"` for a TestFlight App ID.
    public let itemErrors: [(item: String, error: Error)]

    public static let empty = DeploymentFetchResult(deployments: [], itemErrors: [])

    public init(deployments: [Deployment], itemErrors: [(item: String, error: Error)] = []) {
        self.deployments = deployments
        self.itemErrors = itemErrors
    }
}
