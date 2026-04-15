import SwiftUI
import SafariServices

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @State private var showAddIntegration = false
    @State private var safariTarget: SafariTarget?
    @State private var showErrorBanner = true
    @State private var selectedProviderID: String? = nil

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DesignTokens.Palette.background.ignoresSafeArea()

                content

                if appState.isRefreshing {
                    LiquidRefreshIndicator(progress: 1.0, isRefreshing: true)
                        .padding(.top, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.82),
                       value: appState.isRefreshing)
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
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

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if !appState.hasConfiguredProvider {
            emptyStateNoProviders
        } else if filteredDeployments.isEmpty && appState.errors.isEmpty {
            emptyStateNoDeployments
        } else {
            deploymentScroll
        }
    }

    // The configured providers that actually have deployments (used for the
    // pill rail so we don't clutter it with services that never posted anything).
    private var activeProviderIDs: [String] {
        let configured = ServiceRegistry.shared.configuredProviders.map(\.id)
        let withData = Set(appState.sortedDeployments.map(\.providerID))
        return configured.filter { withData.contains($0) }
    }

    private var filteredDeployments: [Deployment] {
        guard let id = selectedProviderID else { return appState.sortedDeployments }
        return appState.sortedDeployments.filter { $0.providerID == id }
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
                    errorBanner
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                LiquidGlassGroup(spacing: 16) {
                    ForEach(filteredDeployments) { deployment in
                        DeploymentCard(deployment: deployment) { url in
                            safariTarget = SafariTarget(url: url)
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

    // MARK: Error banner

    private var errorBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                GlassIconChip(systemImage: "exclamationmark.triangle.fill",
                              tint: .white, size: 32)
                Text("Some services failed to refresh")
                    .font(DesignTokens.Typography.cardTitle)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation { showErrorBanner = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 28, height: 28)
                        .liquidGlassCircle()
                }
                .buttonStyle(.plain)
            }
            ForEach(appState.errors.sorted(by: { $0.key < $1.key }), id: \.key) { providerID, message in
                let name = ServiceRegistry.shared.provider(withID: providerID)?.displayName ?? providerID
                Text("\(name): \(message)")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(2)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(
            GlowBackground(
                theme: .error,
                shape: RoundedRectangle(cornerRadius: DesignTokens.Radius.md,
                                        style: .continuous),
                intensity: 0.9)
        )
    }

    // MARK: Empty states

    private var emptyStateNoProviders: some View {
        EmptyStateCard(
            title: "No Integrations",
            message: "Add an integration to start monitoring deployments.",
            cta: "Add Integration",
            systemImage: "plus"
        ) {
            showAddIntegration = true
        }
        .padding(DesignTokens.Spacing.lg)
    }

    private var emptyStateNoDeployments: some View {
        EmptyStateCard(
            title: "All Quiet",
            message: "No recent deployments. Pull down to refresh.",
            cta: nil,
            systemImage: "clock",
            action: nil
        )
        .padding(DesignTokens.Spacing.lg)
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
                    .frame(width: 38, height: 38)
                    .liquidGlassCircle()
            }
            .accessibilityLabel("Settings")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showAddIntegration = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .liquidGlassCircle()
            }
            .accessibilityLabel("Add Integration")
        }
    }
}

// MARK: - Empty state glass card

private struct EmptyStateCard: View {
    let title: String
    let message: String
    let cta: String?
    let systemImage: String
    var action: (() -> Void)? = nil

    // Rotate through provider themes every 4 seconds so the empty state feels
    // alive and shows off what the app will look like once configured.
    @State private var themeIndex = 0
    private static let rotatingThemes: [ProviderTheme] = [
        .forProviderID("vercel"),
        .forProviderID("cloudflare"),
        .forProviderID("netlify"),
        .forProviderID("flyio"),
        .forProviderID("xcodeCloud"),
    ]

    init(title: String, message: String, cta: String?, systemImage: String,
         action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.cta = cta
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            GlassIconChip(systemImage: systemImage, tint: .white, size: 56)

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(.white)
                Text(message)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.80))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let cta, let action {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: systemImage)
                        Text(cta).fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .liquidGlassChip()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 48)
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            GlowBackground(
                theme: Self.rotatingThemes[themeIndex],
                shape: RoundedRectangle(cornerRadius: DesignTokens.Radius.hero,
                                        style: .continuous),
                intensity: 0.9)
            .animation(.easeInOut(duration: 1.5), value: themeIndex)
        )
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                withAnimation { themeIndex = (themeIndex + 1) % Self.rotatingThemes.count }
            }
        }
    }
}

// MARK: - Last-refresh pill

private struct LastRefreshPill: View {
    let lastRefresh: Date

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var staleness: Color {
        let age = -lastRefresh.timeIntervalSinceNow
        switch age {
        case ..<120:  return DesignTokens.Palette.success
        case ..<600:  return DesignTokens.Palette.building
        default:      return DesignTokens.Palette.queued
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(staleness)
                .frame(width: 6, height: 6)
                .shadow(color: staleness, radius: 4)
            Text("Updated \(Self.relativeFormatter.localizedString(for: lastRefresh, relativeTo: Date()))")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .liquidGlassChip()
    }
}

// MARK: - Sheet item wrapper

struct SafariTarget: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - SafariView wrapper

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
