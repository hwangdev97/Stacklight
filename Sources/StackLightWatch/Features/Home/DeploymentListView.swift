import SwiftUI

struct DeploymentListView: View {
    @EnvironmentObject private var appState: WatchAppState

    var body: some View {
        Group {
            if appState.sortedDeployments.isEmpty {
                EmptyStateView()
            } else {
                List(appState.sortedDeployments) { deployment in
                    NavigationLink {
                        DeploymentDetailView(deployment: deployment)
                    } label: {
                        DeploymentRow(deployment: deployment)
                    }
                }
                .listStyle(.carousel)
            }
        }
        .navigationTitle("StackLight")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    appState.refresh()
                } label: {
                    if appState.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(appState.isRefreshing)
            }
        }
        .refreshable {
            await withCheckedContinuation { cont in
                WatchSessionManager.shared.requestSnapshot { _ in
                    cont.resume()
                }
            }
        }
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No deployments")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Text("Open StackLight on iPhone to configure providers.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
    }
}
