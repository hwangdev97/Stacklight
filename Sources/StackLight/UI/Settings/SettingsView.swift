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
    @State private var selection: SettingsItem = .general  

    var body: some View {
        NavigationSplitView {
            
            List(selection: $selection) {
                
                Section {
                    sidebarRow(title: "General", systemImage: "gear", color: .gray, size: 22)
                        .tag(SettingsItem.general)
                }

                Section("Services") {
                    ForEach(ServiceRegistry.shared.providers, id: \.id) { provider in
                        sidebarRow(provider: provider)
                            .tag(SettingsItem.provider(provider.id))
                    }
                }

                Section {
                    sidebarRow(title: "Send Feedback", systemImage: "bubble.left.and.bubble.right", color: .gray, size: 22, iconSize: 8)
                        .tag(SettingsItem.feedback)
                }
              
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
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
        .frame(width: 660, height: 500)
    }

    @ViewBuilder
    private func sidebarRow(provider: DeploymentProvider) -> some View {
        HStack(spacing: 8) {
            ProviderIconView(provider: provider, size: 22)
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

    @ViewBuilder
    private func sidebarRow(title: String, systemImage: String, color: Color, size: CGFloat = 24, iconSize: CGFloat? = nil, cornerRadius: CGFloat? = nil) -> some View {
        let radius = cornerRadius ?? size * 0.5
        let innerSize = iconSize ?? size * 0.5
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: innerSize, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(color.gradient)
                .overlay(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.plusLighter)
                    .mask(shape.stroke(lineWidth: 1.5))
                )
                .clipShape(shape)
            Text(title)
            Spacer()
        }
    }
}

// MARK: - Previews

#Preview("Settings — Full") {
    SettingsView()
        .environmentObject(AppState())
}
