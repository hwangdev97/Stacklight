import SwiftUI

/// SwiftUI replacement for the former AppKit-based NSMenu. Hosted inside a
/// `MenuBarExtra` with `.menuBarExtraStyle(.window)` so the entire panel is a
/// regular SwiftUI view — previewable and easy to iterate on.
struct MenuBarContentView: View {
    var providers: [DeploymentProvider]
    var deployments: [Deployment]
    var errors: [String: String]
    var lastRefresh: Date?
    var onRefresh: () -> Void
    var onOpenSettings: () -> Void
    var onOpenFeedback: () -> Void
    var onQuit: () -> Void = { NSApp.terminate(nil) }

    @Environment(\.openURL) private var openURL

    private var grouped: [String: [Deployment]] {
        Dictionary(grouping: deployments, by: \.providerID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if providers.isEmpty {
                emptyState
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

            let list = Array((grouped[provider.id] ?? []).prefix(5))
            if list.isEmpty && errors[provider.id] == nil {
                Text("No recent deployments")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            } else {
                ForEach(list, id: \.id) { deployment in
                    deploymentRow(deployment)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Rows

    @ViewBuilder
    private func providerHeader(_ provider: DeploymentProvider) -> some View {
        let hasDashboard = provider.dashboardURL != nil
        MenuRow(isEnabled: hasDashboard) {
            if let url = provider.dashboardURL { openURL(url) }
        } label: {
            HStack(spacing: 8) {
                ProviderIconView(provider: provider, size: 18)
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

    @ViewBuilder
    private func deploymentRow(_ deployment: Deployment) -> some View {
        MenuRow(isEnabled: deployment.url != nil) {
            if let url = deployment.url { openURL(url) }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor(deployment.status))
                    .frame(width: 8, height: 8)
                Text(String(deployment.projectName.prefix(24)))
                    .fontWeight(.semibold)
                    .lineLimit(1)
                if let branch = deployment.branch {
                    let truncated = branch.count > 28 ? String(branch.prefix(26)) + "…" : branch
                    Text(truncated)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Text(deployment.relativeTime)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .help(deployment.commitMessage ?? "")
    }

    @ViewBuilder
    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let lastRefresh {
                Text("Updated \(relativeTime(from: lastRefresh))")
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
            MenuRow(action: onQuit) {
                menuItemLabel("Quit StackLight", shortcut: "⌘Q")
            }
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
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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
        branch: String? = nil,
        commit: String? = nil,
        hasURL: Bool = true
    ) -> Deployment {
        Deployment(
            id: id,
            providerID: providerID,
            projectName: projectName,
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
        deploy("ga1", "githubActions", "stacklight", .success,
               minutesAgo: 4, branch: "main", commit: "ci: cache Swift build"),
        deploy("ga2", "githubActions", "stacklight", .success,
               minutesAgo: 23, branch: "pr/214", commit: "test: cover MenuBarContentView"),
        deploy("ga3", "githubActions", "infra-terraform", .building,
               minutesAgo: 1, branch: "main", hasURL: false),

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
