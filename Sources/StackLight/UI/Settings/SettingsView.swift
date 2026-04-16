import SwiftUI

// MARK: - Sidebar Item

enum SettingsItem: Hashable {
    case provider(String)
    case general
    case feedback
}

// MARK: - Root Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selection: SettingsItem = .provider(ServiceRegistry.shared.providers.first?.id ?? "")

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Services") {
                    ForEach(ServiceRegistry.shared.providers, id: \.id) { provider in
                        sidebarRow(provider: provider)
                            .tag(SettingsItem.provider(provider.id))
                    }
                }
                Section {
                    Label("General", systemImage: "gear")
                        .tag(SettingsItem.general)
                    Label("Send Feedback", systemImage: "bubble.left.and.bubble.right")
                        .tag(SettingsItem.feedback)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            ScrollView {
                Group {
                    switch selection {
                    case .provider(let id):
                        if let provider = ServiceRegistry.shared.provider(withID: id) {
                            ProviderSettingsDetail(provider: provider)
                                .id(id)
                        }
                    case .general:
                        GeneralSettingsDetail()
                    case .feedback:
                        FeedbackView(onOpenGitHubSettings: {
                            selection = .provider("githubPRs")
                        })
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .frame(width: 660, height: 500)
    }

    @ViewBuilder
    private func sidebarRow(provider: DeploymentProvider) -> some View {
        HStack(spacing: 8) {
            ProviderIconView(provider: provider, size: 20, cornerRadius: 5)
            Text(provider.displayName)
            Spacer()
            if provider.isConfigured {
                if appState.errors[provider.id] != nil {
                    Circle().fill(.red).frame(width: 8, height: 8)
                } else {
                    Circle().fill(.green).frame(width: 8, height: 8)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Settings — Full") {
    SettingsView()
        .environmentObject(AppState())
}
