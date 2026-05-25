import SwiftUI
import StackLightCore

/// SwiftUI replacement for the former AppKit-based NSMenu. Hosted inside a
/// `MenuBarExtra` with `.menuBarExtraStyle(.window)` so the entire panel is a
/// regular SwiftUI view — previewable and easy to iterate on.
struct MenuBarContentView: View {
    var providers: [DeploymentProvider]
    var errors: [String: String]
    var lastRefresh: Date?
    /// True while a poll is in flight. Footer swaps "Updated Xm ago" for a
    /// spinner + "Refreshing…" label so users see that fresher data is on
    /// the way after they open the menu.
    var isRefreshing: Bool
    var onRefresh: () -> Void
    var onOpenSettings: () -> Void
    var onOpenFeedback: () -> Void
    var onCheckForUpdates: () -> Void = {
        Task {
            let result: Result<UpdateCheckResult, Error>
            do {
                result = .success(try await UpdateChecker.checkForUpdates())
            } catch {
                result = .failure(error)
            }
            await MainActor.run {
                UpdateChecker.presentUpdateCheckResult(result)
            }
        }
    }
    var onQuit: () -> Void = { NSApp.terminate(nil) }

    /// Pre-grouped deployments keyed by provider ID. The view used to compute
    /// `Dictionary(grouping:)` inline on every body call — pushing this work
    /// up to AppState lets the menu redraw skip the regroup when the data
    /// hasn't actually changed.
    private let grouped: [String: [Deployment]]

    /// Pre-grouped deployments keyed by `projectGroupingKey`, used when
    /// "Group by project" is enabled.
    private let deploymentsByProject: [String: [Deployment]]

    /// Provider lookup by ID so project-mode platform sub-headers can resolve a
    /// row's provider without a linear scan of the registry.
    private let providersByID: [String: DeploymentProvider]

    /// Convenience init for callers (and previews) that have a flat list and
    /// don't want to pre-group themselves.
    init(
        providers: [DeploymentProvider],
        deployments: [Deployment],
        errors: [String: String],
        lastRefresh: Date?,
        isRefreshing: Bool = false,
        onRefresh: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onOpenFeedback: @escaping () -> Void,
        onCheckForUpdates: @escaping () -> Void = {
            Task {
                let result: Result<UpdateCheckResult, Error>
                do {
                    result = .success(try await UpdateChecker.checkForUpdates())
                } catch {
                    result = .failure(error)
                }
                await MainActor.run {
                    UpdateChecker.presentUpdateCheckResult(result)
                }
            }
        },
        onQuit: @escaping () -> Void = { NSApp.terminate(nil) }
    ) {
        self.init(
            providers: providers,
            deploymentsByProvider: Dictionary(grouping: deployments, by: \.providerID),
            deploymentsByProject: Dictionary(grouping: deployments, by: \.projectGroupingKey),
            providersByID: Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) }),
            errors: errors,
            lastRefresh: lastRefresh,
            isRefreshing: isRefreshing,
            onRefresh: onRefresh,
            onOpenSettings: onOpenSettings,
            onOpenFeedback: onOpenFeedback,
            onCheckForUpdates: onCheckForUpdates,
            onQuit: onQuit
        )
    }

    /// Hot-path init used by `MenuBarRootView` — accepts the precomputed
    /// grouped dictionary maintained on AppState so the menu doesn't have to
    /// regroup the flat array on every redraw.
    init(
        providers: [DeploymentProvider],
        deploymentsByProvider: [String: [Deployment]],
        deploymentsByProject: [String: [Deployment]] = [:],
        providersByID: [String: DeploymentProvider] = [:],
        errors: [String: String],
        lastRefresh: Date?,
        isRefreshing: Bool = false,
        onRefresh: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onOpenFeedback: @escaping () -> Void,
        onCheckForUpdates: @escaping () -> Void = {
            Task {
                let result: Result<UpdateCheckResult, Error>
                do {
                    result = .success(try await UpdateChecker.checkForUpdates())
                } catch {
                    result = .failure(error)
                }
                await MainActor.run {
                    UpdateChecker.presentUpdateCheckResult(result)
                }
            }
        },
        onQuit: @escaping () -> Void = { NSApp.terminate(nil) }
    ) {
        self.providers = providers
        self.grouped = deploymentsByProvider
        self.deploymentsByProject = deploymentsByProject
        self.providersByID = providersByID.isEmpty
            ? Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })
            : providersByID
        self.errors = errors
        self.lastRefresh = lastRefresh
        self.isRefreshing = isRefreshing
        self.onRefresh = onRefresh
        self.onOpenSettings = onOpenSettings
        self.onOpenFeedback = onOpenFeedback
        self.onCheckForUpdates = onCheckForUpdates
        self.onQuit = onQuit
    }

    @Environment(\.openURL) private var openURL
    /// Observing the store (rather than snapshotting once) makes the menu react
    /// live to settings changes — the "Group by project" toggle and pin/hide
    /// edits redraw the open panel immediately.
    @ObservedObject private var settingsStore = SettingsStore.shared
    private var settings: UserSettings { settingsStore.settings }

    /// Returns deployments for a provider grouped by visibility:
    /// `(pinned, visible, hidden)`. `hidden` is exposed so the UI can fold it
    /// into a collapsible "Hidden (N)" submenu instead of dropping items.
    private func partitioned(_ list: [Deployment]) -> (pinned: [Deployment], visible: [Deployment], hidden: [Deployment]) {
        var pinned: [Deployment] = []
        var visible: [Deployment] = []
        var hidden: [Deployment] = []
        for deployment in list {
            switch settings.visibility(for: deployment.key) {
            case .pinned: pinned.append(deployment)
            case .visible: visible.append(deployment)
            case .hidden: hidden.append(deployment)
            }
        }
        return (pinned, visible, hidden)
    }

    private func updateVisibility(_ visibility: ItemVisibility, for deployment: Deployment) {
        SettingsStore.shared.mutate { settings in
            settings.setVisibility(visibility, for: deployment.key)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if providers.isEmpty {
                emptyState
            } else if settings.groupByProject {
                projectModeBody
            } else {
                ForEach(Array(providers.enumerated()), id: \.element.id) { idx, provider in
                    if idx > 0 {
                        Divider().padding(.horizontal, 10)
                    }
                    providerSection(provider)
                }
            }

            Divider().padding(.horizontal, 10)

            footer
        }
        .padding(.vertical, 6)
        .frame(width: 320)
    }

    /// Project keys ordered by most-recent deployment first. `deploymentsByProject`
    /// values inherit the flat array's createdAt-desc order, so the first item
    /// in each group is its most recent.
    private var orderedProjectKeys: [String] {
        deploymentsByProject.keys.sorted { lhs, rhs in
            let l = deploymentsByProject[lhs]?.first?.createdAt ?? .distantPast
            let r = deploymentsByProject[rhs]?.first?.createdAt ?? .distantPast
            return l > r
        }
    }

    @ViewBuilder
    private var projectModeBody: some View {
        if orderedProjectKeys.isEmpty {
            Text("No recent deployments")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
        } else {
            ForEach(Array(orderedProjectKeys.enumerated()), id: \.element) { idx, key in
                if idx > 0 {
                    Divider().padding(.horizontal, 10)
                }
                projectSection(key)
            }
        }
    }

    // MARK: - States

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("No services configured")
                .font(.callout.weight(.medium))
            Text("Open Settings to add API tokens")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func providerSection(_ provider: DeploymentProvider) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            providerHeader(provider)

            if let error = errors[provider.id] {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            let list = grouped[provider.id] ?? []
            if list.isEmpty && errors[provider.id] == nil {
                Text("No recent deployments")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            } else {
                rowsBlock(for: list)
            }
        }
        .padding(.vertical, 2)
    }

    /// Shared row block: pinned rows first, then the visible feed (capped at 5),
    /// then a folded "Hidden (N)" submenu. Used by both the provider and project
    /// layouts so they stay in sync.
    @ViewBuilder
    private func rowsBlock(for list: [Deployment]) -> some View {
        let parts = partitioned(list)
        // Pinned rows go first (already labeled with a pin glyph).
        ForEach(parts.pinned, id: \.id) { deployment in
            deploymentRow(deployment, isPinned: true)
        }
        // Then the normal feed (capped at 5 to keep the menu compact).
        ForEach(parts.visible.prefix(5), id: \.id) { deployment in
            deploymentRow(deployment, isPinned: false)
        }
        // Hidden items collapse into a folded count so the user can unhide
        // without opening Settings.
        if !parts.hidden.isEmpty {
            Menu {
                ForEach(parts.hidden, id: \.id) { deployment in
                    Button("Show \(deployment.projectName)") {
                        updateVisibility(.visible, for: deployment)
                    }
                }
            } label: {
                Text("Hidden (\(parts.hidden.count))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .menuStyle(.borderlessButton)
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
        }
    }

    // MARK: - Project mode

    @ViewBuilder
    private func projectSection(_ key: String) -> some View {
        let items = deploymentsByProject[key] ?? []
        VStack(alignment: .leading, spacing: 0) {
            projectHeader(for: items)

            // Sub-group the project's deployments by platform, ordered by the
            // most-recent deployment in each platform (items are already
            // createdAt-desc, so first wins).
            let byProvider = Dictionary(grouping: items, by: \.providerID)
            let orderedProviderIDs = byProvider.keys.sorted { lhs, rhs in
                let l = byProvider[lhs]?.first?.createdAt ?? .distantPast
                let r = byProvider[rhs]?.first?.createdAt ?? .distantPast
                return l > r
            }
            ForEach(orderedProviderIDs, id: \.self) { providerID in
                if let provider = providersByID[providerID] {
                    providerHeader(provider, compact: true)
                }
                rowsBlock(for: byProvider[providerID] ?? [])
            }
        }
        .padding(.vertical, 2)
    }

    /// Non-clickable project header. A project can span platforms, so unlike a
    /// provider header there's no single dashboard to open. Display name is the
    /// most-recent item's repository when known, else its project name. The
    /// group is the top-level unit in this mode, so it carries the prominent
    /// filled badge (brand-colored, from the most-recent deployment's provider)
    /// while the per-platform sub-headers below it are rendered plain.
    @ViewBuilder
    private func projectHeader(for items: [Deployment]) -> some View {
        let representative = items.first
        let name: String = {
            if let repo = representative?.repository, !repo.isEmpty { return repo }
            if let project = representative?.projectName, !project.isEmpty { return project }
            return "Other"
        }()
        HStack(spacing: 8) {
            if let providerID = representative?.providerID,
               let provider = providersByID[providerID] {
                ProviderIconView(provider: provider, size: 18)
            } else {
                Image(systemName: "folder.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.secondary.gradient, in: Circle())
            }
            Text(name)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    // MARK: - Rows

    /// `compact` is used for the per-platform sub-headers inside a project
    /// group: the group already owns the prominent filled badge, so here we
    /// drop the brand-colored circle and show just a small monochrome glyph.
    @ViewBuilder
    private func providerHeader(_ provider: DeploymentProvider, compact: Bool = false) -> some View {
        let hasDashboard = provider.dashboardURL != nil
        MenuRow(isEnabled: hasDashboard) {
            if let url = provider.dashboardURL { openURL(url) }
        } label: {
            HStack(spacing: 8) {
                if compact {
                    providerGlyph(provider)
                } else {
                    ProviderIconView(provider: provider, size: 18)
                }
                Text(provider.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if hasDashboard {
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    /// Plain (no filled circle) provider glyph used for compact sub-headers.
    /// Tinted `.secondary` so it stays legible in both light and dark menus —
    /// some brand colors (Vercel, GitHub) are near-black and would vanish.
    @ViewBuilder
    private func providerGlyph(_ provider: DeploymentProvider) -> some View {
        Group {
            if let asset = provider.iconAsset {
                Image(asset)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: provider.iconSymbol)
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .frame(width: 14, height: 14)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func deploymentRow(_ deployment: Deployment, isPinned: Bool = false) -> some View {
        MenuRow(isEnabled: deployment.url != nil) {
            if let url = deployment.url { openURL(url) }
        } label: {
            HStack(spacing: 8) {
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                } else {
                    Circle()
                        .fill(statusColor(deployment.status))
                        .frame(width: 8, height: 8)
                }
                Text(String(deployment.projectName.prefix(24)))
                    .fontWeight(.semibold)
                    .lineLimit(1)
                if let repository = deployment.repository, repository != deployment.projectName {
                    Text(repository)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let branch = deployment.branch {
                    let truncated = branch.count > 28 ? String(branch.prefix(26)) + "…" : branch
                    Text(truncated)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Text(deployment.relativeTime)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .help(deployment.commitMessage ?? "")
        .contextMenu {
            let current = settings.visibility(for: deployment.key)
            Button {
                updateVisibility(current == .pinned ? .visible : .pinned, for: deployment)
            } label: {
                Label(current == .pinned ? "Unpin" : "Pin", systemImage: "pin")
            }
            Button {
                updateVisibility(.hidden, for: deployment)
            } label: {
                Label("Hide", systemImage: "eye.slash")
            }
            if current != .visible {
                Button {
                    updateVisibility(.visible, for: deployment)
                } label: {
                    Label("Reset", systemImage: "arrow.uturn.backward")
                }
            }
            if let url = deployment.url {
                Divider()
                Button("Open in Browser") { openURL(url) }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isRefreshing {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.6)
                        .frame(width: 10, height: 10)
                    Text("Refreshing…")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 2)
            } else if let lastRefresh {
                let configuredCount = providers.count
                let okCount = max(0, configuredCount - errors.count)
                Text("Updated \(relativeTime(from: lastRefresh)) · \(okCount)/\(configuredCount) ok")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
            }

            MenuRow(action: onRefresh) {
                menuItemLabel("Refresh Now", shortcut: "⌘R")
            }

            Divider().padding(.horizontal, 10).padding(.vertical, 2)

            MenuRow(action: onOpenSettings) {
                menuItemLabel("Settings…", shortcut: "⌘,")
            }
            MenuRow(action: onOpenFeedback) {
                menuItemLabel("Send Feedback…")
            }
            MenuRow(action: onCheckForUpdates) {
                menuItemLabel(updateMenuTitle)
            }
            MenuRow(action: onQuit) {
                menuItemLabel("Quit StackLight", shortcut: "⌘Q")
            }
        }
    }

    private var updateMenuTitle: String {
        switch UpdateChecker.channel {
        case .github:
            return "Check for Updates…"
        case .macAppStore:
            return "Updates via Mac App Store"
        case .development:
            return "Check for Updates…"
        }
    }

    @ViewBuilder
    private func menuItemLabel(_ title: String, shortcut: String? = nil) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let shortcut {
                Text(shortcut)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Helpers

    private func statusColor(_ status: Deployment.Status) -> Color {
        switch status {
        case .success:   return .green
        case .failed:    return .red
        case .building:  return .orange
        case .queued:    return .gray
        case .cancelled: return .gray
        case .reviewing: return .blue
        case .unknown:   return .gray
        }
    }

    private func relativeTime(from date: Date) -> String {
        SharedFormatters.relativeAbbreviated.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Row styling

/// Hover-highlighted menu row with an accent-tinted background on hover.
private struct MenuRow<Label: View>: View {
    var isEnabled: Bool = true
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            label()
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .background {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isHovering && isEnabled ? Color.accentColor.opacity(0.15) : Color.clear)
                .padding(.horizontal, 6)
        }
        .foregroundStyle(isEnabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
        .onHover { hovering in
            guard isEnabled else { return }
            isHovering = hovering
        }
    }
}

// MARK: - Preview fixtures

private enum PreviewFixtures {
    /// All nine real providers, treated as if every one were configured.
    static let allProviders: [DeploymentProvider] = [
        VercelProvider(),
        CloudflareProvider(),
        GitHubActionsProvider(),
        GitHubPRProvider(),
        NetlifyProvider(),
        RailwayProvider(),
        FlyioProvider(),
        XcodeCloudProvider(),
        TestFlightProvider()
    ]

    static func deploy(
        _ id: String,
        _ providerID: String,
        _ projectName: String,
        _ status: Deployment.Status,
        minutesAgo: Double,
        repository: String? = nil,
        branch: String? = nil,
        commit: String? = nil,
        hasURL: Bool = true
    ) -> Deployment {
        Deployment(
            id: id,
            providerID: providerID,
            projectName: projectName,
            repository: repository,
            status: status,
            url: hasURL ? URL(string: "https://example.com/\(id)") : nil,
            createdAt: Date().addingTimeInterval(-minutesAgo * 60),
            commitMessage: commit,
            branch: branch
        )
    }

    static let richDeployments: [Deployment] = [
        // Vercel — mixed states, multiple projects
        deploy("v1", "vercel", "marketing-site", .success,
               minutesAgo: 2, branch: "main", commit: "fix: typo in hero copy"),
        deploy("v2", "vercel", "api-gateway", .building,
               minutesAgo: 0.5, branch: "feature/rate-limit", commit: "wip: sliding window limiter", hasURL: false),
        deploy("v3", "vercel", "dashboard", .failed,
               minutesAgo: 35, branch: "release/2024.11", commit: "chore: bump deps"),
        deploy("v4", "vercel", "landing", .queued,
               minutesAgo: 0.2, branch: "main", hasURL: false),

        // Cloudflare — long branch, long project name
        deploy("c1", "cloudflare", "docs-site", .failed,
               minutesAgo: 9, branch: "hotfix/broken-search-index", commit: "hotfix: restore search index"),
        deploy("c2", "cloudflare", "customer-portal-next", .success,
               minutesAgo: 58, branch: "main", commit: "feat: add SSO provider selector"),
        deploy("c3", "cloudflare", "edge-worker", .cancelled,
               minutesAgo: 210, branch: "experiment/geo-routing", commit: "try: route by POP"),

        // GitHub Actions — matrix-like
        deploy("ga1", "githubActions", "Release", .success,
               minutesAgo: 120, repository: "stacklight", branch: "v1.0.25"),
        deploy("ga2", "githubActions", "CI", .success,
               minutesAgo: 23, repository: "stacklight", branch: "pr/214",
               commit: "test: cover MenuBarContentView"),
        deploy("ga3", "githubActions", "Plan", .building,
               minutesAgo: 1, repository: "infra-terraform", branch: "main", hasURL: false),

        // GitHub PRs — each as its own "deployment" row
        deploy("pr1", "githubPRs", "#214 Menubar preview fixtures", .reviewing,
               minutesAgo: 11, branch: "feat/menubar-swiftui"),
        deploy("pr2", "githubPRs", "#213 Grouped Form settings", .success,
               minutesAgo: 90, branch: "feat/form-grouped"),
        deploy("pr3", "githubPRs", "#209 Brand color icons", .success,
               minutesAgo: 1440, branch: "feat/brand-colors"),

        // Netlify
        deploy("n1", "netlify", "blog", .success,
               minutesAgo: 15, branch: "main", commit: "post: Liquid Glass on macOS"),
        deploy("n2", "netlify", "status-page", .building,
               minutesAgo: 0.8, branch: "main", hasURL: false),

        // Railway
        deploy("r1", "railway", "worker-svc", .success,
               minutesAgo: 6, branch: "main", commit: "perf: batch redis writes"),
        deploy("r2", "railway", "metrics-ingest", .failed,
               minutesAgo: 48, branch: "main", commit: "oops: dropped conn pool"),

        // Fly.io
        deploy("f1", "flyio", "auth-service", .success,
               minutesAgo: 3, branch: "main", commit: "chore: rotate jwt keys"),
        deploy("f2", "flyio", "auth-service", .cancelled,
               minutesAgo: 27, branch: "main"),

        // Xcode Cloud
        deploy("xc1", "xcodeCloud", "StackLight", .building,
               minutesAgo: 0.3, branch: "main", hasURL: false),
        deploy("xc2", "xcodeCloud", "StackLight", .success,
               minutesAgo: 62, branch: "release/1.1", commit: "bump: 1.1.0 (42)"),
        deploy("xc3", "xcodeCloud", "StackLight", .failed,
               minutesAgo: 180, branch: "main", commit: "add: NotificationCenter mocks"),

        // TestFlight — reviewing & unknown
        deploy("tf1", "testFlight", "StackLight 1.1.0 (42)", .reviewing,
               minutesAgo: 120),
        deploy("tf2", "testFlight", "StackLight 1.0.9 (41)", .success,
               minutesAgo: 2880),
        deploy("tf3", "testFlight", "StackLight 1.0.8 (40)", .unknown,
               minutesAgo: 4320)
    ]
}

// MARK: - Previews

#Preview("Menubar — Populated (all providers)") {
    MenuBarContentView(
        providers: PreviewFixtures.allProviders,
        deployments: PreviewFixtures.richDeployments,
        errors: [:],
        lastRefresh: Date().addingTimeInterval(-5),
        onRefresh: {},
        onOpenSettings: {},
        onOpenFeedback: {},
        onQuit: {}
    )
}

#Preview("Menubar — A couple providers") {
    MenuBarContentView(
        providers: [VercelProvider(), CloudflareProvider(), NetlifyProvider()],
        deployments: PreviewFixtures.richDeployments,
        errors: [:],
        lastRefresh: Date().addingTimeInterval(-12),
        onRefresh: {},
        onOpenSettings: {},
        onOpenFeedback: {},
        onQuit: {}
    )
}

#Preview("Menubar — Errors everywhere") {
    MenuBarContentView(
        providers: [VercelProvider(), GitHubActionsProvider(), NetlifyProvider()],
        deployments: Array(PreviewFixtures.richDeployments.prefix(3)),
        errors: [
            "vercel": "Unauthorized (401). Check your API token in Settings.",
            "githubActions": "Rate limited by GitHub API — retry in 42s.",
            "netlify": "Network is unreachable (NSURLErrorNotConnectedToInternet)."
        ],
        lastRefresh: Date().addingTimeInterval(-300),
        onRefresh: {},
        onOpenSettings: {},
        onOpenFeedback: {},
        onQuit: {}
    )
}

#Preview("Menubar — No deployments yet") {
    MenuBarContentView(
        providers: [VercelProvider(), NetlifyProvider()],
        deployments: [],
        errors: [:],
        lastRefresh: Date(),
        onRefresh: {},
        onOpenSettings: {},
        onOpenFeedback: {},
        onQuit: {}
    )
}

#Preview("Menubar — Refreshing") {
    MenuBarContentView(
        providers: PreviewFixtures.allProviders,
        deployments: PreviewFixtures.richDeployments,
        errors: [:],
        lastRefresh: Date().addingTimeInterval(-240),
        isRefreshing: true,
        onRefresh: {},
        onOpenSettings: {},
        onOpenFeedback: {},
        onQuit: {}
    )
}

#Preview("Menubar — Empty (unconfigured)") {
    MenuBarContentView(
        providers: [],
        deployments: [],
        errors: [:],
        lastRefresh: nil,
        onRefresh: {},
        onOpenSettings: {},
        onOpenFeedback: {},
        onQuit: {}
    )
}
