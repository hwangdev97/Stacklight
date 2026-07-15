import SwiftUI
import StackLightCore

/// Content of the hover panel shown next to a failed deployment row.
/// Renders whatever `FailureDetailsStore` knows about the failure and offers
/// copy/handoff actions. Lives inside a non-activating, non-key NSPanel —
/// so it must never require keyboard focus (no text fields, no focus rings).
struct ErrorDetailCard: View {
    let deployment: Deployment
    let providerName: String

    @ObservedObject private var store = FailureDetailsStore.shared
    @Environment(\.openURL) private var openURL

    /// Transient "Copied ✓" style feedback line.
    @State private var feedback: String?
    @State private var feedbackDismiss: Task<Void, Never>?

    static let cardWidth: CGFloat = 380

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            content
            Divider()
            actions
            if let feedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(14)
        .frame(width: Self.cardWidth, alignment: .leading)
        .background(HoverCardBackground())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .onAppear { store.load(deployment) }
    }

    // MARK: - Sections

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                Text(deployment.projectName)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(providerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Text("\(deployment.status.displayName) · \(deployment.relativeTime)")
                if let branch = deployment.branch, !branch.isEmpty {
                    Text("· \(branch)")
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let commit = deployment.commitMessage?.split(separator: "\n").first {
                Text(String(commit))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state(for: deployment) {
        case .loading, nil:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Fetching error details…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)

        case .unsupported:
            VStack(alignment: .leading, spacing: 4) {
                Text("\(providerName) doesn’t expose failure logs through its API.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("You can still copy the build metadata for an AI agent, or open the dashboard for the full story.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .failed(let message):
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Couldn’t load error details: \(message)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Move away and hover again to retry.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }

        case .loaded(let details):
            loadedContent(details)
        }
    }

    @ViewBuilder
    private func loadedContent(_ details: DeploymentFailureDetails) -> some View {
        if details.isEmpty {
            Text("The build failed, but \(providerName) returned no error output. Open the logs for the full story.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if let summary = details.summary {
                    Text(summary)
                        .font(.caption.weight(.medium))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !details.issues.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(details.issues.prefix(5).enumerated()), id: \.offset) { _, issue in
                            issueRow(issue)
                        }
                        if details.issues.count > 5 {
                            Text("+ \(details.issues.count - 5) more")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                if let excerpt = details.logExcerpt {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(details.logExcerptTruncated ? "Log tail (truncated)" : "Log")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                        ScrollView(.vertical) {
                            Text(excerpt)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(6)
                        }
                        .frame(maxHeight: 180)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func issueRow(_ issue: DeploymentFailureDetails.Issue) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: issue.severity == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(issue.severity == .error ? .red : .yellow)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(issue.message)
                    .font(.caption)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if let source = issue.source {
                    Text(source)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                copy(feedbackText: "Copied — paste into your agent") {
                    await store.agentPrompt(for: deployment)
                }
            } label: {
                Label("Copy for Agent", systemImage: "sparkles")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                copy(feedbackText: "Error details copied") {
                    await store.plainErrorText(for: deployment)
                }
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Menu {
                ForEach(AIErrorHandoffCLI.allCases, id: \.rawValue) { cli in
                    Button("Open in \(cli.displayName)…") {
                        openInAgent(cli)
                    }
                }
            } label: {
                Image(systemName: "terminal")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Copy the prompt and launch an agent CLI in Terminal")

            Spacer(minLength: 0)

            if let logsURL = currentLogsURL {
                Button {
                    openURL(logsURL)
                } label: {
                    Label("Logs", systemImage: "arrow.up.right")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var currentLogsURL: URL? {
        if case .loaded(let details) = store.state(for: deployment), let url = details.logsURL {
            return url
        }
        return deployment.url
    }

    // MARK: - Actions

    private func copy(feedbackText: String, _ payload: @escaping () async -> String) {
        Task { @MainActor in
            let text = await payload()
            AgentHandoff.copyToPasteboard(text)
            showFeedback(feedbackText)
        }
    }

    private func openInAgent(_ cli: AIErrorHandoffCLI) {
        Task { @MainActor in
            let prompt = await store.agentPrompt(for: deployment)
            showFeedback(AgentHandoff.launchInTerminal(cli, prompt: prompt))
        }
    }

    private func showFeedback(_ message: String) {
        feedback = message
        feedbackDismiss?.cancel()
        feedbackDismiss = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            feedback = nil
        }
    }
}

/// Popover-style translucency for the hover card. The panel itself is
/// transparent; this view provides the visible surface.
private struct HoverCardBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
