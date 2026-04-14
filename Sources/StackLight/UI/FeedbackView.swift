import SwiftUI

struct FeedbackView: View {
    /// Optional callback the host can provide so we can switch the Settings sidebar
    /// to the GitHub PR provider when the user has not configured a token yet.
    var onOpenGitHubSettings: (() -> Void)?

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var category: FeedbackCategory = .bug
    @State private var isSubmitting = false
    @State private var submittedURL: URL?
    @State private var errorMessage: String?
    @State private var hasToken: Bool = FeedbackView.tokenPresent()

    private var canSubmit: Bool {
        !isSubmitting
            && hasToken
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header — matches ProviderSettingsDetail style
            VStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, height: 56)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("Send Feedback")
                    .font(.title2.weight(.semibold))

                Text("Posted as a GitHub issue in \(FeedbackService.repository).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            // Missing-token banner
            if !hasToken {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("No GitHub token set. Add a Personal Access Token in GitHub Pull Requests settings to enable feedback.")
                        .font(.caption)
                        .lineLimit(3)
                    Spacer()
                    if let onOpenGitHubSettings {
                        Button("Open GitHub Settings") {
                            onOpenGitHubSettings()
                        }
                        .controlSize(.small)
                    }
                }
                .padding(10)
                .background(.yellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            // Form card
            VStack(spacing: 0) {
                // Category
                HStack {
                    Text("Category")
                        .frame(width: 100, alignment: .leading)
                        .foregroundStyle(.primary)
                    Picker("", selection: $category) {
                        ForEach(FeedbackCategory.allCases) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)

                Divider().padding(.leading, 16)

                // Title
                HStack {
                    Text("Title")
                        .frame(width: 100, alignment: .leading)
                        .foregroundStyle(.primary)
                    TextField("", text: $title, prompt: Text("Short summary"))
                        .textFieldStyle(.plain)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)

                Divider().padding(.leading, 16)

                // Description
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .foregroundStyle(.primary)
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $description)
                            .font(.body)
                            .frame(minHeight: 140)
                            .scrollContentBackground(.hidden)
                        if description.isEmpty {
                            Text("Tell us what happened, what you expected, and any steps to reproduce.")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(6)
                    .background(.background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 0.5)
                    )
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            )
            .padding(.horizontal, 20)

            // Action row
            HStack(spacing: 12) {
                Button("Submit") {
                    submit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)

                if isSubmitting {
                    ProgressView().controlSize(.small)
                }

                Spacer()

                if let submittedURL {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Submitted")
                            .foregroundStyle(.green)
                        Link("View issue", destination: submittedURL)
                    }
                    .font(.caption)
                    .transition(.opacity)
                } else if let errorMessage {
                    Label(String(errorMessage.prefix(60)), systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                        .help(errorMessage)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .animation(.easeInOut(duration: 0.2), value: submittedURL)
            .animation(.easeInOut(duration: 0.2), value: errorMessage)

            Spacer(minLength: 20)
        }
        .onAppear { hasToken = FeedbackView.tokenPresent() }
    }

    private func submit() {
        let payload = FeedbackPayload(
            title: title,
            category: category,
            description: description
        )
        isSubmitting = true
        errorMessage = nil
        submittedURL = nil

        Task {
            do {
                let url = try await FeedbackService.submit(payload)
                submittedURL = url
                title = ""
                description = ""
                isSubmitting = false

                // Auto-fade the confirmation after a short delay.
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                if submittedURL == url { submittedURL = nil }
            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
                hasToken = FeedbackView.tokenPresent()
            }
        }
    }

    private static func tokenPresent() -> Bool {
        guard let token = KeychainManager.read(key: "github.token") else { return false }
        return !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
