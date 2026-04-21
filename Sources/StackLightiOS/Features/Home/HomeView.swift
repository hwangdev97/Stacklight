import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @State private var showAddIntegration = false
    @State private var safariTarget: SafariTarget?
    @State private var showErrorBanner = true
    @State private var selectedProviderID: String? = nil

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DesignTokens.Palette.background.ignoresSafeArea()

                content

                if appState.isRefreshing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.82),
                       value: appState.isRefreshing)
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { toolbarContent }
            .refreshable {
                appState.refresh()
                try? await Task.sleep(nanoseconds: 600_000_000)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environmentObject(appState)
            }
            .sheet(isPresented: $showAddIntegration) {
                AddIntegrationView().environmentObject(appState)
            }
            .sheet(item: $safariTarget) { target in
                SafariView(url: target.url).ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }

    // MARK: Content branching

    @ViewBuilder
    private var content: some View {
        if !appState.hasConfiguredProvider {
            EmptyStateCard(
                title: "No Integrations",
                message: "Add an integration to start monitoring deployments.",
                cta: "Add Integration",
                systemImage: "plus"
            ) {
                showAddIntegration = true
            }
            .padding(DesignTokens.Spacing.lg)
        } else if filteredDeployments.isEmpty && appState.errors.isEmpty {
            EmptyStateCard(
                title: "All Quiet",
                message: "No recent deployments. Pull down to refresh.",
                cta: nil,
                systemImage: "clock"
            )
            .padding(DesignTokens.Spacing.lg)
        } else {
            deploymentScroll
        }
    }

    // MARK: Derived data

    private var activeProviderIDs: [String] { appState.activeProviderIDs }

    private var filteredDeployments: [Deployment] {
        appState.filteredDeployments(for: selectedProviderID)
    }

    // MARK: Scroll list

    private var deploymentScroll: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.md) {
                if !activeProviderIDs.isEmpty {
                    ProjectPillRail(
                        selectedProviderID: $selectedProviderID,
                        providerIDs: activeProviderIDs)
                }

                if !appState.errors.isEmpty && showErrorBanner {
                    HomeErrorBanner(errors: appState.errors) {
                        withAnimation { showErrorBanner = false }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                LiquidGlassGroup(spacing: 16) {
                    VStack(spacing: DesignTokens.Spacing.md) {
                        ForEach(filteredDeployments) { deployment in
                            DeploymentCard(deployment: deployment) { url in
                                safariTarget = SafariTarget(url: url)
                            }
                            .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                

                if let lastRefresh = appState.lastRefresh {
                    LastRefreshPill(lastRefresh: lastRefresh)
                        .padding(.top, DesignTokens.Spacing.sm)
                        .padding(.bottom, DesignTokens.Spacing.xxl)
                }
            }
            .padding(.top, DesignTokens.Spacing.xs)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .hoverEffect(.highlight)
            .keyboardShortcut(",", modifiers: .command)
            .accessibilityLabel("Settings")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                appState.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .hoverEffect(.highlight)
            .keyboardShortcut("r", modifiers: .command)
            .accessibilityLabel("Refresh")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showAddIntegration = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .hoverEffect(.highlight)
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityLabel("Add Integration")
        }
    }
}

// MARK: - Previews

#if DEBUG
@MainActor
private func previewState(
    deployments: [Deployment] = [],
    errors: [String: String] = [:],
    lastRefresh: Date? = nil,
    isRefreshing: Bool = false,
    hasProviders: Bool = true
) -> AppState {
    let state = AppState()
    state.deployments = deployments
    state.errors = errors
    state.lastRefresh = lastRefresh
    state.isRefreshing = isRefreshing
    state.previewConfiguredOverride = hasProviders
    return state
}

private let previewDeployments: [Deployment] = [
    Deployment(
        id: "1",
        providerID: "vercel",
        projectName: "marketing-site",
        status: .success,
        url: URL(string: "https://vercel.com"),
        createdAt: Date().addingTimeInterval(-120),
        commitMessage: "Update landing copy",
        branch: "main"
    ),
    Deployment(
        id: "2",
        providerID: "cloudflare",
        projectName: "docs",
        status: .building,
        url: URL(string: "https://cloudflare.com"),
        createdAt: Date().addingTimeInterval(-30),
        commitMessage: "Rework nav",
        branch: "feat/nav"
    ),
    Deployment(
        id: "3",
        providerID: "netlify",
        projectName: "blog",
        status: .failed,
        url: URL(string: "https://netlify.com"),
        createdAt: Date().addingTimeInterval(-900),
        commitMessage: "Fix broken build",
        branch: "fix/build"
    ),
    Deployment(
        id: "4",
        providerID: "flyio",
        projectName: "api",
        status: .queued,
        url: nil,
        createdAt: Date().addingTimeInterval(-60),
        commitMessage: "Deploy edge workers",
        branch: "main"
    ),
]

#Preview("No Integrations") {
    HomeView()
        .environmentObject(previewState(hasProviders: false))
}

#Preview("With Deployments") {
    HomeView()
        .environmentObject(previewState(
            deployments: previewDeployments,
            lastRefresh: Date().addingTimeInterval(-45)
        ))
}

#Preview("Refreshing") {
    HomeView()
        .environmentObject(previewState(
            deployments: previewDeployments,
            lastRefresh: Date().addingTimeInterval(-45),
            isRefreshing: true
        ))
}

#Preview("With Errors") {
    HomeView()
        .environmentObject(previewState(
            deployments: previewDeployments,
            errors: [
                "vercel": "401 Unauthorized — token expired",
                "githubActions": "Network connection lost",
            ],
            lastRefresh: Date().addingTimeInterval(-600)
        ))
}

#Preview("Empty — No Deployments") {
    HomeView()
        .environmentObject(previewState(
            lastRefresh: Date()
        ))
}
#endif
