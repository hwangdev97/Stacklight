import Foundation
import SwiftUI

public final class SupabaseProvider: DeploymentProvider {
    public let id = "supabase"
    public let displayName = "Supabase"
    public let iconSymbol = "bolt.horizontal.fill"
    public let color = Color(red: 0.24, green: 0.80, blue: 0.52)
    public let docsURL = URL(string: "https://supabase.com/docs/reference/api/getting-started")

    static let tokenKey = "supabase.token"
    static let projectRefsKey = "supabase.projectRefs"
    static let showBranchesKey = "supabase.showBranches"
    static let showActionRunsKey = "supabase.showActionRuns"
    static let hideInactiveKey = "supabase.hideInactiveProjects"
    private static let maxActionRunsPerProject = 5

    public init() {}

    public var dashboardURL: URL? {
        let refs = parsedProjectRefs()
        if refs.count == 1 {
            return URL(string: "https://supabase.com/dashboard/project/\(refs[0])")
        }
        return URL(string: "https://supabase.com/dashboard/projects")
    }

    public var isConfigured: Bool {
        guard let token = KeychainManager.read(key: Self.tokenKey) else { return false }
        return !token.isEmpty
    }

    public func fetchDeployments() async throws -> DeploymentFetchResult {
        guard let token = KeychainManager.read(key: Self.tokenKey), !token.isEmpty else {
            return .empty
        }

        let refs = parsedProjectRefs()
        let projectLoad: (projects: [SupabaseProject], errors: [(item: String, error: Error)])
        if refs.isEmpty {
            projectLoad = (try await Self.fetchProjects(token: token), [])
        } else {
            projectLoad = await Self.fetchConfiguredProjects(token: token, refs: refs)
        }

        let filteredProjects = AppConfig.bool(forKey: Self.hideInactiveKey)
            ? projectLoad.projects.filter { $0.status.uppercased() != "INACTIVE" }
            : projectLoad.projects

        let snapshotResult = await Self.fetchProjectSnapshots(
            token: token,
            projects: filteredProjects,
            includeBranches: AppConfig.bool(forKey: Self.showBranchesKey),
            includeActionRuns: AppConfig.bool(forKey: Self.showActionRunsKey)
        )

        return DeploymentFetchResult(
            deployments: snapshotResult.deployments,
            itemErrors: projectLoad.errors + snapshotResult.itemErrors
        )
    }

    public func settingsFields() -> [SettingsField] {
        [
            SettingsField(
                key: Self.tokenKey,
                label: "Access Token",
                isSecret: true,
                placeholder: "Supabase personal access token",
                hint: "Create a personal access token in Supabase account settings."
            ),
            SettingsField(
                key: Self.projectRefsKey,
                label: "Project Refs",
                placeholder: "abcdefghijklmnopqrst",
                isMultiValue: true,
                hint: "Leave empty to auto-discover all projects available to the token."
            ),
            SettingsField(
                key: Self.showBranchesKey,
                label: "Show Branches",
                hint: "Include Supabase preview and persistent branch environments.",
                kind: .toggle
            ),
            SettingsField(
                key: Self.showActionRunsKey,
                label: "Show Action Runs",
                hint: "Include the latest branch push, merge, reset, and deploy workflows.",
                kind: .toggle
            ),
            SettingsField(
                key: Self.hideInactiveKey,
                label: "Hide Inactive Projects",
                hint: "Paused Supabase projects won't appear in the list.",
                kind: .toggle
            )
        ]
    }

    private func parsedProjectRefs() -> [String] {
        Self.parseProjectRefs(AppConfig.string(forKey: Self.projectRefsKey))
    }

    static func parseProjectRefs(_ raw: String?) -> [String] {
        (raw ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .reduce(into: []) { refs, ref in
                if !refs.contains(ref) {
                    refs.append(ref)
                }
            }
    }

    private static func fetchProjectSnapshots(
        token: String,
        projects: [SupabaseProject],
        includeBranches: Bool,
        includeActionRuns: Bool
    ) async -> DeploymentFetchResult {
        await withTaskGroup(of: SupabaseProjectSnapshot.self) { group in
            for project in projects {
                group.addTask {
                    await Self.fetchProjectSnapshot(
                        token: token,
                        project: project,
                        includeBranches: includeBranches,
                        includeActionRuns: includeActionRuns
                    )
                }
            }

            var deployments: [Deployment] = []
            var errors: [(item: String, error: Error)] = []
            for await snapshot in group {
                deployments.append(contentsOf: snapshot.deployments)
                errors.append(contentsOf: snapshot.errors)
            }
            return DeploymentFetchResult(deployments: deployments, itemErrors: errors)
        }
    }

    private static func fetchProjectSnapshot(
        token: String,
        project: SupabaseProject,
        includeBranches: Bool,
        includeActionRuns: Bool
    ) async -> SupabaseProjectSnapshot {
        async let healthResult = fetchServiceHealthResult(token: token, ref: project.ref)
        async let branchesResult = (includeBranches || includeActionRuns)
            ? fetchBranchesResult(token: token, ref: project.ref)
            : .success([])
        async let actionsResult = includeActionRuns
            ? fetchActionRunsResult(token: token, ref: project.ref)
            : .success([])

        var errors: [(item: String, error: Error)] = []

        let health: [SupabaseServiceHealth]
        switch await healthResult {
        case .success(let services):
            health = services
        case .failure(let error):
            health = []
            errors.append((item: "\(project.ref) health", error: error))
        }

        let branches: [SupabaseBranch]
        switch await branchesResult {
        case .success(let loaded):
            branches = loaded
        case .failure(let error):
            branches = []
            errors.append((item: "\(project.ref) branches", error: error))
        }

        let actions: [SupabaseActionRun]
        switch await actionsResult {
        case .success(let loaded):
            actions = loaded
        case .failure(let error):
            actions = []
            errors.append((item: "\(project.ref) actions", error: error))
        }

        var deployments = [
            project.toDeployment(health: health)
        ]

        if includeBranches {
            deployments.append(contentsOf: branches
                .filter { !$0.isDefault }
                .map { $0.toDeployment(project: project) })
        }

        if includeActionRuns {
            let branchNamesByID = branches.reduce(into: [String: String]()) { names, branch in
                names[branch.id] = branch.name
            }
            deployments.append(contentsOf: actions.prefix(Self.maxActionRunsPerProject).map {
                $0.toDeployment(project: project, branchName: branchNamesByID[$0.branchID])
            })
        }

        return SupabaseProjectSnapshot(deployments: deployments, errors: errors)
    }

    private static func fetchProjects(token: String) async throws -> [SupabaseProject] {
        let data = try await get(token: token, path: "/v1/projects")
        return try SharedJSON.iso8601FractionalDecoder.decode([SupabaseProject].self, from: data)
    }

    private static func fetchProject(token: String, ref: String) async throws -> SupabaseProject {
        let data = try await get(token: token, path: "/v1/projects/\(ref)")
        return try SharedJSON.iso8601FractionalDecoder.decode(SupabaseProject.self, from: data)
    }

    private static func fetchConfiguredProjects(
        token: String,
        refs: [String]
    ) async -> (projects: [SupabaseProject], errors: [(item: String, error: Error)]) {
        await withTaskGroup(of: (String, Result<SupabaseProject, Error>).self) { group in
            for ref in refs {
                group.addTask {
                    do {
                        return (ref, .success(try await fetchProject(token: token, ref: ref)))
                    } catch {
                        return (ref, .failure(error))
                    }
                }
            }

            var projects: [SupabaseProject] = []
            var errors: [(item: String, error: Error)] = []
            for await (ref, result) in group {
                switch result {
                case .success(let project):
                    projects.append(project)
                case .failure(let error):
                    errors.append((item: ref, error: error))
                }
            }
            return (projects, errors)
        }
    }

    private static func fetchServiceHealthResult(
        token: String,
        ref: String
    ) async -> Result<[SupabaseServiceHealth], Error> {
        do {
            return .success(try await fetchServiceHealth(token: token, ref: ref))
        } catch {
            return .failure(error)
        }
    }

    private static func fetchBranchesResult(token: String, ref: String) async -> Result<[SupabaseBranch], Error> {
        do {
            return .success(try await fetchBranches(token: token, ref: ref))
        } catch {
            return .failure(error)
        }
    }

    private static func fetchActionRunsResult(token: String, ref: String) async -> Result<[SupabaseActionRun], Error> {
        do {
            return .success(try await fetchActionRuns(token: token, ref: ref))
        } catch {
            return .failure(error)
        }
    }

    private static func fetchServiceHealth(token: String, ref: String) async throws -> [SupabaseServiceHealth] {
        let data = try await get(token: token, path: "/v1/projects/\(ref)/health")
        return try SharedJSON.decoder.decode([SupabaseServiceHealth].self, from: data)
    }

    private static func fetchBranches(token: String, ref: String) async throws -> [SupabaseBranch] {
        let data = try await get(token: token, path: "/v1/projects/\(ref)/branches")
        return try SharedJSON.iso8601FractionalDecoder.decode([SupabaseBranch].self, from: data)
    }

    private static func fetchActionRuns(token: String, ref: String) async throws -> [SupabaseActionRun] {
        let data = try await get(token: token, path: "/v1/projects/\(ref)/actions")
        return try SharedJSON.iso8601FractionalDecoder.decode([SupabaseActionRun].self, from: data)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private static func get(token: String, path: String) async throws -> Data {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.supabase.com"
        components.path = path
        guard let url = components.url else {
            throw ProviderError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await RequestRunner.shared.execute(request: request)
        guard response.statusCode == 200 else {
            let message = (try? SharedJSON.decoder.decode(SupabaseErrorResponse.self, from: data))?.bestMessage
                ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            throw ProviderError.http(code: response.statusCode, message: message, body: data)
        }
        return data
    }
}

// MARK: - Mapping

private struct SupabaseProjectSnapshot {
    let deployments: [Deployment]
    let errors: [(item: String, error: Error)]
}

private struct SupabaseErrorResponse: Decodable {
    let error: String?
    let message: String?

    var bestMessage: String? {
        if let message, !message.isEmpty { return message }
        if let error, !error.isEmpty { return error }
        return nil
    }
}

private struct SupabaseProject: Decodable {
    let ref: String
    let name: String
    let region: String
    let createdAt: Date
    let status: String

    enum CodingKeys: String, CodingKey {
        case ref, name, region, status
        case createdAt = "created_at"
    }

    func toDeployment(health: [SupabaseServiceHealth]) -> Deployment {
        let unhealthyServices = health
            .filter { $0.status.uppercased() == "UNHEALTHY" || $0.healthy == false }
            .map(\.name)
            .sorted()

        let serviceSummary: String?
        if unhealthyServices.isEmpty {
            serviceSummary = "Region \(region)"
        } else {
            serviceSummary = "Unhealthy: \(unhealthyServices.joined(separator: ", "))"
        }

        return Deployment(
            id: "supabase-project-\(ref)",
            providerID: "supabase",
            projectName: name,
            status: SupabaseStatusMapper.combinedProjectStatus(projectStatus: status, health: health),
            url: URL(string: "https://supabase.com/dashboard/project/\(ref)"),
            createdAt: createdAt,
            commitMessage: serviceSummary,
            branch: "production"
        )
    }

}

struct SupabaseServiceHealth: Decodable {
    let name: String
    let healthy: Bool?
    let status: String
}

private struct SupabaseBranch: Decodable {
    let id: String
    let name: String
    let projectRef: String
    let parentProjectRef: String
    let isDefault: Bool
    let gitBranch: String?
    let prNumber: Int?
    let persistent: Bool
    let status: String?
    let createdAt: Date
    let updatedAt: Date
    let previewProjectStatus: String?
    let deletionScheduledAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, status, persistent
        case projectRef = "project_ref"
        case parentProjectRef = "parent_project_ref"
        case isDefault = "is_default"
        case gitBranch = "git_branch"
        case prNumber = "pr_number"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case previewProjectStatus = "preview_project_status"
        case deletionScheduledAt = "deletion_scheduled_at"
    }

    func toDeployment(project: SupabaseProject) -> Deployment {
        let branchName = gitBranch ?? name
        let summary: String
        if let prNumber {
            summary = "PR #\(prNumber)"
        } else if persistent {
            summary = "Persistent branch"
        } else {
            summary = "Preview branch"
        }

        return Deployment(
            id: "supabase-branch-\(id)",
            providerID: "supabase",
            projectName: "\(project.name) · \(branchName)",
            status: deletionScheduledAt == nil
                ? SupabaseStatusMapper.branchStatus(status: status, previewProjectStatus: previewProjectStatus)
                : .cancelled,
            url: URL(string: "https://supabase.com/dashboard/project/\(projectRef)"),
            createdAt: updatedAt,
            commitMessage: summary,
            branch: branchName
        )
    }
}

private struct SupabaseActionRun: Decodable {
    let id: String
    let branchID: String
    let runSteps: [RunStep]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case branchID = "branch_id"
        case runSteps = "run_steps"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    struct RunStep: Decodable {
        let name: String
        let status: String
        let createdAt: Date
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case name, status
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    func toDeployment(project: SupabaseProject, branchName: String?) -> Deployment {
        let label = branchName ?? "workflow"
        let currentStep = runSteps
            .sorted { $0.updatedAt > $1.updatedAt }
            .first

        return Deployment(
            id: "supabase-action-\(id)",
            providerID: "supabase",
            projectName: "\(project.name) · \(label)",
            status: SupabaseStatusMapper.actionStatus(runSteps.map {
                SupabaseStatusMapper.ActionStep(name: $0.name, status: $0.status)
            }),
            url: URL(string: "https://supabase.com/dashboard/project/\(project.ref)"),
            createdAt: updatedAt,
            commitMessage: currentStep.map { "\($0.name.capitalized): \($0.status.capitalized)" },
            branch: branchName
        )
    }
}

enum SupabaseStatusMapper {
    struct ActionStep {
        let name: String
        let status: String
    }

    static func projectStatus(_ status: String) -> Deployment.Status {
        switch status.uppercased() {
        case "ACTIVE_HEALTHY": return .success
        case "COMING_UP", "RESTORING", "UPGRADING", "RESTARTING", "RESIZING": return .building
        case "INACTIVE", "GOING_DOWN", "PAUSING", "REMOVED": return .cancelled
        case "ACTIVE_UNHEALTHY", "INIT_FAILED", "RESTORE_FAILED", "PAUSE_FAILED": return .failed
        default: return .unknown
        }
    }

    static func combinedProjectStatus(
        projectStatus: String,
        health: [SupabaseServiceHealth]
    ) -> Deployment.Status {
        let serviceStatuses = health.map { $0.status.uppercased() }
        if serviceStatuses.contains("UNHEALTHY") || health.contains(where: { $0.healthy == false }) {
            return .failed
        }
        if serviceStatuses.contains("COMING_UP") {
            return .building
        }
        return self.projectStatus(projectStatus)
    }

    static func branchStatus(status: String?, previewProjectStatus: String?) -> Deployment.Status {
        if let previewProjectStatus {
            return self.projectStatus(previewProjectStatus)
        }

        switch status?.uppercased() {
        case "CREATING_PROJECT", "RUNNING_MIGRATIONS": return .building
        case "MIGRATIONS_PASSED", "FUNCTIONS_DEPLOYED": return .success
        case "MIGRATIONS_FAILED", "FUNCTIONS_FAILED": return .failed
        default: return .unknown
        }
    }

    static func actionStatus(_ steps: [ActionStep]) -> Deployment.Status {
        let statuses = steps.map { $0.status.uppercased() }
        if statuses.contains("DEAD") { return .failed }
        if statuses.contains(where: { ["RUNNING", "RESTARTING", "REMOVING"].contains($0) }) {
            return .building
        }
        if statuses.contains("CREATED") { return .queued }
        if statuses.contains("PAUSED") { return .cancelled }
        if !steps.isEmpty && statuses.allSatisfy({ $0 == "EXITED" }) { return .success }
        return .unknown
    }
}
