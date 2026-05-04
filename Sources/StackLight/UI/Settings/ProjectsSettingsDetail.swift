import SwiftUI
import StackLightCore

/// Centralized pin/hide management for every deployment the app has seen.
/// Mirrors RepoBar's "Repositories" browser — visibility persists even when a
/// project temporarily disappears from API results, so the user can diagnose
/// "why did X vanish from my menu?" without losing their preferences.
struct ProjectsSettingsDetail: View {
    @EnvironmentObject var appState: AppState
    @State private var settings: UserSettings = SettingsStore.shared.load()
    @State private var searchText: String = ""

    /// Union of currently-fetched deployments and items that have a saved
    /// visibility but aren't in the current fetch (e.g. hidden items still
    /// appear here so they can be unhidden).
    private var allKnownDeployments: [Deployment] {
        var seen: [String: Deployment] = [:]
        for deployment in appState.deployments {
            seen[deployment.key.rawValue] = deployment
        }
        // Surface saved keys that aren't currently fetched as placeholder rows
        // so they can be reset / unhidden from this screen.
        let savedKeys = settings.pinnedItems.union(settings.hiddenItems)
        for raw in savedKeys where seen[raw] == nil {
            guard let key = DeploymentKey(rawValue: raw) else { continue }
            seen[raw] = Deployment(
                id: key.itemID,
                providerID: key.providerID,
                projectName: key.itemID,
                status: .unknown,
                url: nil,
                createdAt: .distantPast,
                commitMessage: nil,
                branch: nil
            )
        }
        return seen.values.sorted { lhs, rhs in
            if lhs.providerID != rhs.providerID { return lhs.providerID < rhs.providerID }
            return lhs.projectName < rhs.projectName
        }
    }

    private var filteredDeployments: [Deployment] {
        guard !searchText.isEmpty else { return allKnownDeployments }
        let needle = searchText.lowercased()
        return allKnownDeployments.filter {
            $0.projectName.lowercased().contains(needle) ||
            $0.providerID.lowercased().contains(needle) ||
            ($0.repository?.lowercased().contains(needle) ?? false)
        }
    }

    var body: some View {
        Form {
            VStack(spacing: 8) {
                GlassDetailIcon(color: .gray, systemImage: "rectangle.stack")
                Text("Projects")
                    .font(.title2.weight(.semibold))
                Text("Pin the projects you care about, hide the noise.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                TextField("Search by project, repository, or provider", text: $searchText)
                    .textFieldStyle(.plain)
            }

            if filteredDeployments.isEmpty {
                Text(searchText.isEmpty ? "No deployments fetched yet — once polling completes, projects will appear here." : "No matches.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Section {
                    ForEach(filteredDeployments, id: \.key.rawValue) { deployment in
                        projectRow(deployment)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: SettingsStore.didChange)) { _ in
            settings = SettingsStore.shared.load()
        }
    }

    @ViewBuilder
    private func projectRow(_ deployment: Deployment) -> some View {
        let current = settings.visibility(for: deployment.key)
        HStack(spacing: 10) {
            if let providerLogo = deployment.providerID as String? {
                Text(providerInitial(for: providerLogo))
                    .font(.caption.weight(.bold))
                    .frame(width: 22, height: 22)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(deployment.projectName)
                    .lineLimit(1)
                Text(displayProviderName(deployment.providerID))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: Binding(
                get: { current },
                set: { newValue in
                    SettingsStore.shared.mutate { $0.setVisibility(newValue, for: deployment.key) }
                    settings = SettingsStore.shared.load()
                }
            )) {
                ForEach(ItemVisibility.allCases, id: \.self) { state in
                    Label(state.displayName, systemImage: state.systemImage)
                        .tag(state)
                }
            }
            .labelsHidden()
            .frame(width: 110)
        }
        .padding(.vertical, 2)
    }

    private func providerInitial(for providerID: String) -> String {
        String(providerID.prefix(1).uppercased())
    }

    private func displayProviderName(_ providerID: String) -> String {
        ServiceRegistry.shared.provider(withID: providerID)?.displayName ?? providerID
    }
}
