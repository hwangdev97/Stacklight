import SwiftUI

struct ProviderSettingsView: View {
    let provider: DeploymentProvider
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var fieldValues: [String: String] = [:]
    @State private var saved = false
    @State private var testing = false
    @State private var testResult: TestResult?
    @State private var showDeleteConfirm = false

    /// When true, Save dismisses back to caller (used from AddIntegrationView).
    var dismissOnSave: Bool = false

    private enum TestResult {
        case success(Int)
        case failure(String)
    }

    var body: some View {
        Form {
            headerSection

            if let error = appState.errors[provider.id] {
                Section {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error).font(.caption)
                    }
                }
            }

            credentialSections

            multiValueSections

            actionSection

            if provider.isConfigured {
                deleteSection
            }
        }
        .navigationTitle(provider.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadFields)
        .confirmationDialog(
            "Delete \(provider.displayName) integration?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteIntegration() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your credentials will be removed from the keychain.")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: provider.iconSymbol)
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, height: 56)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(provider.displayName)
                    .font(.headline)

                if let docsURL = provider.docsURL {
                    Link(destination: docsURL) {
                        HStack(spacing: 4) {
                            Text("How to get credentials")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.caption)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var credentialSections: some View {
        let singleFields = provider.settingsFields().filter { !$0.isMultiValue }
        if !singleFields.isEmpty {
            Section("Credentials") {
                ForEach(singleFields) { field in
                    VStack(alignment: .leading, spacing: 4) {
                        if field.isSecret {
                            SecureField(field.placeholder, text: binding(for: field))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            TextField(field.placeholder, text: binding(for: field))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        Text(field.label)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        if let hint = field.hint {
                            Text(hint)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var multiValueSections: some View {
        ForEach(provider.settingsFields().filter(\.isMultiValue)) { field in
            MultiValueFieldSection(field: field, rawValue: binding(for: field))
        }
    }

    private var actionSection: some View {
        Section {
            Button {
                saveAndRestart()
            } label: {
                HStack {
                    Label("Save", systemImage: "checkmark")
                    Spacer()
                    if saved {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
            }

            Button {
                Task { await testConnection() }
            } label: {
                HStack {
                    Label("Test Connection", systemImage: "network")
                    Spacer()
                    if testing {
                        ProgressView()
                    } else if let result = testResult {
                        switch result {
                        case .success(let count):
                            Label("\(count)", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .labelStyle(.titleAndIcon)
                                .font(.caption)
                        case .failure(let msg):
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .help(msg)
                        }
                    }
                }
            }
            .disabled(testing)
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete Integration", systemImage: "trash")
            }
        }
    }

    // MARK: - Bindings & Persistence

    private func binding(for field: SettingsField) -> Binding<String> {
        Binding(
            get: { fieldValues[field.key] ?? "" },
            set: { fieldValues[field.key] = $0 }
        )
    }

    private func loadFields() {
        for field in provider.settingsFields() {
            if field.isSecret {
                fieldValues[field.key] = KeychainManager.read(key: field.key) ?? ""
            } else {
                fieldValues[field.key] = UserDefaults.standard.string(forKey: field.key) ?? ""
            }
        }
    }

    private func saveFields() {
        for field in provider.settingsFields() {
            let value = (fieldValues[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if field.isSecret {
                if value.isEmpty {
                    KeychainManager.delete(key: field.key)
                } else {
                    try? KeychainManager.save(key: field.key, value: value)
                }
            } else {
                UserDefaults.standard.set(value, forKey: field.key)
            }
        }
        ASCCredentialStore.invalidate()
    }

    private func saveAndRestart() {
        saveFields()
        appState.restartPolling()
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { saved = false }
            if dismissOnSave {
                dismiss()
            }
        }
    }

    private func testConnection() async {
        saveFields()
        testing = true
        testResult = nil
        do {
            let deployments = try await provider.fetchDeployments()
            testResult = .success(deployments.count)
        } catch {
            testResult = .failure(error.localizedDescription)
        }
        testing = false
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        testResult = nil
    }

    private func deleteIntegration() {
        for field in provider.settingsFields() {
            if field.isSecret {
                KeychainManager.delete(key: field.key)
            } else {
                UserDefaults.standard.removeObject(forKey: field.key)
            }
            fieldValues[field.key] = ""
        }
        appState.restartPolling()
        dismiss()
    }
}

// MARK: - Multi-value Field

private struct MultiValueFieldSection: View {
    let field: SettingsField
    @Binding var rawValue: String
    @State private var newItem: String = ""

    private var items: [String] {
        rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        Section {
            ForEach(items, id: \.self) { item in
                HStack {
                    Text(item)
                        .font(.body.monospaced())
                        .lineLimit(1)
                    Spacer()
                    Button(role: .destructive) {
                        removeItem(item)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField(field.placeholder, text: $newItem)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(addItem)
                Button(action: addItem) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(newItem.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text(field.label)
        } footer: {
            if let hint = field.hint {
                Text(hint)
            }
        }
    }

    private func addItem() {
        let trimmed = newItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var current = items
        if !current.contains(trimmed) {
            current.append(trimmed)
            rawValue = current.joined(separator: ", ")
        }
        newItem = ""
    }

    private func removeItem(_ item: String) {
        let filtered = items.filter { $0 != item }
        rawValue = filtered.joined(separator: ", ")
    }
}
