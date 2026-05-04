import SwiftUI
import StackLightCore

/// Detail pane of `HomeSplitView`. Renders the deployment list as a 2–3 column
/// adaptive grid so wide iPad screens aren't wasted on a single column.
struct DeploymentGridView: View {
    @EnvironmentObject var appState: AppState

    let selectedProviderID: String?
    var onOpenURL: (URL) -> Void
    var onAddIntegration: () -> Void

    @State private var showErrorBanner: Bool = true

    private let columns = [
        GridItem(.adaptive(minimum: 340, maximum: 520),
                 spacing: DesignTokens.Spacing.md,
                 alignment: .top)
    ]

    var body: some View {
        ZStack {
            DesignTokens.Palette.background.ignoresSafeArea()

            content

            if appState.isRefreshing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(.top, 8)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82),
                   value: appState.isRefreshing)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .refreshable {
            appState.refresh()
            try? await Task.sleep(nanoseconds: 600_000_000)
        }
    }

    // MARK: Title

    private var title: String {
        guard let id = selectedProviderID,
              let provider = ServiceRegistry.shared.provider(withID: id) else {
            return "Deployments"
        }
        return provider.displayName
    }

    // MARK: Content

    private var filteredDeployments: [Deployment] {
        appState.filteredDeployments(for: selectedProviderID)
    }

    @ViewBuilder
    private var content: some View {
        if !appState.hasConfiguredProvider {
            EmptyStateCard(
                title: "No Integrations",
                message: "Add an integration to start monitoring deployments.",
                cta: "Add Integration",
                systemImage: "plus"
            ) {
                onAddIntegration()
            }
            .padding(DesignTokens.Spacing.xl)
            .frame(maxWidth: 520)
        } else if filteredDeployments.isEmpty && appState.errors.isEmpty {
            EmptyStateCard(
                title: "All Quiet",
                message: "No recent deployments. Pull down to refresh.",
                cta: nil,
                systemImage: "clock"
            )
            .padding(DesignTokens.Spacing.xl)
            .frame(maxWidth: 520)
        } else {
            deploymentGrid
        }
    }

    private var deploymentGrid: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.md) {
                if !appState.errors.isEmpty && showErrorBanner {
                    HomeErrorBanner(errors: appState.errors) {
                        withAnimation { showErrorBanner = false }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.md) {
                    ForEach(filteredDeployments) { deployment in
                        DeploymentCard(deployment: deployment) { url in
                            onOpenURL(url)
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
            .padding(.top, DesignTokens.Spacing.sm)
        }
    }
}
