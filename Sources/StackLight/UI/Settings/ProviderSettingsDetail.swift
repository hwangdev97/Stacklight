import AppKit
import SwiftUI
import StackLightCore

// MARK: - Provider Detail (System Settings style)

struct ProviderSettingsDetail: View {
    let provider: DeploymentProvider
    /// Navigates the Settings window to the Logs pane. Injected by
    /// `SettingsView`; nil in previews.
    var onOpenLogs: (() -> Void)? = nil
    @State private var fieldValues: [String: String] = [:]
    @State private var saved = false
    @State private var testing = false
    @State private var testResult: TestResult?
    @State private var aiHandoffStatus: String?
    /// Last Test's per-entry error dict, keyed by the entry identifier the
    /// provider reports (e.g. "owner/repo" for GitHub, "12345" for a
    /// TestFlight App ID). Forwarded to `MultiValueFieldView` so individual
    /// chip rows can show an inline exclamation badge.
    @State private var itemErrors: [String: String] = [:]
    @EnvironmentObject var appState: AppState

    private enum TestResult {
        case success(count: Int, failedItems: Int)
        case failure(String)
    }

    var body: some View {
        Form {
            VStack(spacing: 8) {
                providerDetailIcon(provider)

                Text(provider.displayName)
                    .font(.title2.weight(.semibold))

                if let docsURL = provider.docsURL {
                    Link(destination: docsURL) {
                        HStack(spacing: 2) {
                            Text("How to get credentials")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.caption)
                    }
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .center)

            if let error = appState.errors[provider.id] {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text(error)
                                .font(.caption)
                                .lineLimit(4)
                                .textSelection(.enabled)
                            Spacer()
                            if let onOpenLogs {
                                Button("View Logs", action: onOpenLogs)
                                    .buttonStyle(.link)
                                    .font(.caption)
                            }
                        }
                        aiHandoffControls
                    }
                }
            }

            let singleValueFields = provider.settingsFields().filter { !$0.isMultiValue }
            if !singleValueFields.isEmpty {
                Section {
                    ForEach(singleValueFields, id: \.id) { field in
                        VStack(alignment: .leading, spacing: 2) {
                            fieldRow(field)

                            if let hint = field.hint {
                                Text(hint)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            ForEach(provider.settingsFields().filter { $0.isMultiValue }, id: \.id) { field in
                Section {
                    MultiValueFieldView(field: field, rawValue: binding(for: field), itemErrors: itemErrors)
                }
            }

            // Full-width, selectable rendering of the last Test failure. The
            // compact label next to the Test button gets squeezed to nothing
            // when the window is narrow, so the actual message lives here.
            if case .failure(let message)? = testResult {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("Test failed")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            if let onOpenLogs {
                                Button("View Logs", action: onOpenLogs)
                                    .buttonStyle(.link)
                                    .font(.caption)
                            }
                        }
                        Text(message)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Section {
                HStack(spacing: 12) {
                    Button("Save") {
                        saveFields()
                        saved = true
                        appState.restartPolling()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                    }
                    .keyboardShortcut(.defaultAction)

                    Button {
                        copyConfigurationPrompt()
                    } label: {
                        Label("Copy Prompt", systemImage: "sparkles")
                    }
                    .help("Copy a prompt you can paste into an AI assistant (Claude, Codex, …) to get step-by-step help configuring \(provider.displayName).")

                    if saved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .transition(.opacity.combined(with: .scale))
                    }

                    Spacer()

                    if let testResult {
                        Group {
                            switch testResult {
                            case let .success(count, failedItems):
                                if failedItems == 0 {
                                    Label("\(count) deployments", systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    HStack(spacing: 8) {
                                        Label("\(count) ok · \(failedItems) failed", systemImage: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                            .help(itemErrors
                                                .map { "\($0.key): \($0.value)" }
                                                .sorted()
                                                .joined(separator: "\n"))
                                        aiHandoffMenu
                                    }
                                }
                            case .failure(let msg):
                                HStack(spacing: 8) {
                                    Label("Failed", systemImage: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                        .help(msg)
                                    aiHandoffMenu
                                }
                            }
                        }
                        .font(.caption)
                        .transition(.opacity)
                    }

                    if let aiHandoffStatus {
                        Text(aiHandoffStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }

                    Button {
                        testConnection()
                    } label: {
                        if testing {
                            ProgressView().controlSize(.small).frame(width: 40)
                        } else {
                            Text("Test").frame(width: 40)
                        }
                    }
                    .disabled(testing)
                }
            }
        }
        .formStyle(.grouped)
        .animation(.easeInOut(duration: 0.2), value: saved)
        .animation(.easeInOut(duration: 0.2), value: aiHandoffStatus)
        .onAppear { loadFields() }
    }

    @ViewBuilder
    private var aiHandoffControls: some View {
        HStack(spacing: 8) {
            Button {
                copyAIHandoffPrompt()
            } label: {
                Label("Copy for AI", systemImage: "doc.on.doc")
            }

            aiHandoffMenu
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var aiHandoffMenu: some View {
        Menu {
            Button {
                openAIHandoff(.codex)
            } label: {
                Label("Open in Codex", systemImage: "terminal")
            }
            Button {
                openAIHandoff(.claude)
            } label: {
                Label("Open in Claude", systemImage: "terminal")
            }
        } label: {
            Label("Send to AI", systemImage: "sparkles")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    @ViewBuilder
    private func fieldRow(_ field: SettingsField) -> some View {
        switch field.kind {
        case .toggle:
            Toggle(field.label, isOn: toggleBinding(for: field))
        case .branchPicker(let branchesKey):
            LabeledContent(field.label) {
                BranchPickerControl(
                    value: binding(for: field),
                    branchesKey: branchesKey,
                    placeholder: field.placeholder
                )
            }
        case .text:
            LabeledContent(field.label) {
                if field.isSecret {
                    SecureField("", text: binding(for: field), prompt: Text(field.placeholder))
                        .multilineTextAlignment(.trailing)
                } else {
                    TextField("", text: binding(for: field), prompt: Text(field.placeholder))
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private func binding(for field: SettingsField) -> Binding<String> {
        Binding(
            get: { fieldValues[field.key] ?? "" },
            set: { fieldValues[field.key] = $0 }
        )
    }

    private func toggleBinding(for field: SettingsField) -> Binding<Bool> {
        Binding(
            get: { (fieldValues[field.key] ?? "") == "1" },
            set: { fieldValues[field.key] = $0 ? "1" : "0" }
        )
    }

    private func loadFields() {
        for field in provider.settingsFields() {
            if field.isSecret {
                fieldValues[field.key] = KeychainManager.read(key: field.key) ?? ""
            } else if field.isToggle {
                fieldValues[field.key] = AppConfig.bool(forKey: field.key) ? "1" : "0"
            } else {
                fieldValues[field.key] = AppConfig.string(forKey: field.key) ?? ""
            }
        }
    }

    private func testConnection() {
        saveFields()
        testing = true
        testResult = nil
        aiHandoffStatus = nil
        itemErrors = [:]
        Task {
            do {
                let result = try await provider.fetchDeployments()
                var errDict: [String: String] = [:]
                for entry in result.itemErrors {
                    errDict[entry.item] = entry.error.localizedDescription
                }
                itemErrors = errDict
                testResult = .success(count: result.deployments.count, failedItems: result.itemErrors.count)
                if !result.itemErrors.isEmpty {
                    let summary = result.itemErrors
                        .map { "\($0.item): \($0.error.localizedDescription)" }
                        .joined(separator: "; ")
                    await DiagnosticsLogger.shared.warning(
                        "Test: \(result.itemErrors.count) item(s) failed — \(summary)",
                        category: provider.id
                    )
                }
            } catch {
                testResult = .failure(error.localizedDescription)
                await DiagnosticsLogger.shared.error(
                    "Test failed: \(error.localizedDescription)",
                    category: provider.id
                )
            }
            testing = false
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            // Success auto-clears after 5s; failures stay up until the next
            // Test so the message can't vanish before it's been read.
            if case .success? = testResult {
                testResult = nil
            }
            // Keep itemErrors visible on the chip rows until the user edits
            // the list or re-runs Test. Clearing them here would make the
            // badges vanish after 5s which is worse UX.
        }
    }

    @ViewBuilder
    private func providerDetailIcon(_ provider: DeploymentProvider) -> some View {
        GlassDetailIcon(
            color: provider.color,
            systemImage: provider.iconAsset == nil ? provider.iconSymbol : nil,
            asset: provider.iconAsset
        )
    }

    private func saveFields() {
        let fields = provider.settingsFields()

        // Batch every non-secret field into a single SettingsStore.mutate so
        // saving N fields encodes the envelope and fires didChange once
        // instead of N times.
        SettingsStore.shared.mutate { settings in
            for field in fields where !field.isSecret {
                let value = (fieldValues[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if field.isToggle {
                    settings.setBool(value == "1", for: field.key)
                } else {
                    settings.setString(value, for: field.key)
                }
            }
        }

        // Secret fields go to Keychain — separate backing store, must run
        // outside the settings transaction.
        for field in fields where field.isSecret {
            let value = (fieldValues[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty {
                KeychainManager.delete(key: field.key)
            } else {
                try? KeychainManager.save(key: field.key, value: value)
            }
        }
        ASCCredentialStore.invalidate()
    }

    private func copyConfigurationPrompt() {
        let prompt = ProviderSetupPrompt.prompt(for: ProviderSetupContext(
            providerID: provider.id,
            providerName: provider.displayName,
            isConfigured: provider.isConfigured,
            docsURL: provider.docsURL?.absoluteString,
            fields: provider.settingsFields().map { field in
                ProviderSetupField(
                    key: field.key,
                    label: field.label,
                    isSecret: field.isSecret,
                    isMultiValue: field.isMultiValue,
                    isPresent: isFieldPresent(field),
                    kind: handoffKindName(for: field),
                    placeholder: field.placeholder,
                    hint: field.hint
                )
            }
        ))
        copyToPasteboard(prompt)
        setAIHandoffStatus("Copied setup prompt")
    }

    private func copyAIHandoffPrompt() {
        guard let prompt = makeAIHandoffPrompt() else {
            setAIHandoffStatus("No error details to copy")
            return
        }
        copyToPasteboard(prompt)
        setAIHandoffStatus("Copied AI prompt")
    }

    private func openAIHandoff(_ cli: AIErrorHandoffCLI) {
        guard let prompt = makeAIHandoffPrompt() else {
            setAIHandoffStatus("No error details to send")
            return
        }

        copyToPasteboard(prompt)

        do {
            let scriptURL = try writeAICommandScript(for: cli, prompt: prompt)
            if NSWorkspace.shared.open(scriptURL) {
                setAIHandoffStatus("Copied prompt and opened \(cli.displayName)")
            } else {
                setAIHandoffStatus("Copied prompt; could not open \(cli.displayName)")
            }
        } catch {
            setAIHandoffStatus("Copied prompt; \(error.localizedDescription)")
        }
    }

    private func makeAIHandoffPrompt() -> String? {
        let testFailure: String?
        switch testResult {
        case .failure(let message):
            testFailure = message
        case .success, .none:
            testFailure = nil
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return AIErrorHandoff.prompt(for: AIErrorHandoffContext(
            providerID: provider.id,
            providerName: provider.displayName,
            isConfigured: provider.isConfigured,
            providerError: appState.errors[provider.id],
            testFailure: testFailure,
            itemErrors: itemErrors,
            fields: provider.settingsFields().map { field in
                AIErrorHandoffField(
                    key: field.key,
                    label: field.label,
                    isSecret: field.isSecret,
                    isPresent: isFieldPresent(field),
                    isMultiValue: field.isMultiValue,
                    kind: handoffKindName(for: field)
                )
            },
            appVersion: version
        ))
    }

    private func isFieldPresent(_ field: SettingsField) -> Bool {
        let value = fieldValues[field.key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !value.isEmpty
    }

    private func handoffKindName(for field: SettingsField) -> String {
        switch field.kind {
        case .text: return "text"
        case .toggle: return "toggle"
        case .branchPicker: return "branch picker"
        }
    }

    private func copyToPasteboard(_ prompt: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
    }

    private func setAIHandoffStatus(_ message: String) {
        aiHandoffStatus = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if aiHandoffStatus == message {
                aiHandoffStatus = nil
            }
        }
    }

    private func writeAICommandScript(for cli: AIErrorHandoffCLI, prompt: String) throws -> URL {
        let filename = "StackLight-\(cli.executableName)-\(UUID().uuidString).command"
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let quotedPrompt = AIErrorHandoff.shellQuoted(prompt)
        let quotedExecutable = AIErrorHandoff.shellQuoted(cli.executableName)
        let script = """
        #!/bin/zsh
        export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

        if ! command -v \(quotedExecutable) >/dev/null 2>&1; then
          echo "\(cli.displayName) CLI not found."
          echo "The StackLight error prompt has been copied to the clipboard."
          echo "Install \(cli.displayName) CLI or paste the prompt into your AI assistant."
          echo
          read -r "?Press Return to close."
          exit 127
        fi

        \(cli.executableName) \(quotedPrompt)
        status=$?
        echo
        echo "\(cli.displayName) exited with status $status."
        read -r "?Press Return to close."
        exit $status
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        return scriptURL
    }
}

// MARK: - Branch Picker

/// Dropdown that backs a free-form string setting. When known branches have
/// been cached (from a previous `fetchDeployments()` call) they show up as
/// menu items; otherwise the user gets "All", "main", and a "Custom…" escape
/// hatch that reveals an inline text field.
struct BranchPickerControl: View {
    @Binding var value: String
    let branchesKey: String
    let placeholder: String

    @State private var showCustomField: Bool = false
    @State private var customDraft: String = ""

    private static let allOption = ""
    private static let customSentinel = "__custom__"

    private var knownBranches: [String] {
        AppConfig.stringArray(forKey: branchesKey)
    }

    private var options: [String] {
        var opts = [Self.allOption, "main"]
        for branch in knownBranches where !opts.contains(branch) {
            opts.append(branch)
        }
        return opts
    }

    private var selectedOption: String {
        // If the stored value matches one of the menu options, select it;
        // otherwise treat it as a custom entry.
        if value.isEmpty { return Self.allOption }
        return options.contains(value) ? value : Self.customSentinel
    }

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: Binding(
                get: { selectedOption },
                set: { newSelection in
                    if newSelection == Self.customSentinel {
                        showCustomField = true
                        customDraft = options.contains(value) ? "" : value
                    } else {
                        showCustomField = false
                        value = newSelection
                    }
                }
            )) {
                Text("All branches").tag(Self.allOption)
                ForEach(options.filter { $0 != Self.allOption }, id: \.self) { branch in
                    Text(branch).tag(branch)
                }
                Divider()
                Text("Custom…").tag(Self.customSentinel)
            }
            .labelsHidden()
            .fixedSize()

            if showCustomField || (!value.isEmpty && !options.contains(value)) {
                TextField("", text: Binding(
                    get: { customDraft.isEmpty ? value : customDraft },
                    set: { newValue in
                        customDraft = newValue
                        value = newValue.trimmingCharacters(in: .whitespaces)
                    }
                ), prompt: Text(placeholder.isEmpty ? "branch-name" : placeholder))
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 140)
            }
        }
        .onAppear {
            if !value.isEmpty && !options.contains(value) {
                showCustomField = true
                customDraft = value
            }
        }
    }
}

// MARK: - Previews

#Preview("Settings — Provider") {
    ProviderSettingsDetail(provider: ServiceRegistry.shared.providers.first!)
        .environmentObject(AppState())
        .frame(width: 480, height: 500)
}
