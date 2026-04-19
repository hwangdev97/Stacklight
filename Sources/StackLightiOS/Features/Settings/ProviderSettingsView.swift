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
    @FocusState private var focusedKey: String?

    /// When true, Save dismisses back to caller (used from AddIntegrationView).
    var dismissOnSave: Bool = false

    private enum TestResult {
        case success(Int)
        case failure(String)
    }

    private var theme: ProviderTheme { ProviderTheme.forProviderID(provider.id) }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .top) {
            DesignTokens.Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.md) {
                    heroBanner

                    if let error = appState.errors[provider.id] {
                        errorRow(error)
                    }

                    credentialCard

                    multiValueCards

                    actionCard

                    if provider.isConfigured {
                        deleteCard
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.xxl)
            }
        }
        .navigationTitle(provider.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .tint(.white)
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

    // MARK: Hero banner

    private var heroBanner: some View {
        ZStack {
            VStack(spacing: DesignTokens.Spacing.sm) {
                GlassIconChip(provider: provider,
                              tint: theme.accent, size: 58)

                Text(provider.displayName)
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(.white)

                if let docsURL = provider.docsURL {
                    Link(destination: docsURL) {
                        HStack(spacing: 4) {
                            Text("How to get credentials")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(DesignTokens.Typography.chipLabel)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .liquidGlassChip()
                    }
                }
            }
            .padding(.vertical, DesignTokens.Spacing.xl)
            .frame(maxWidth: .infinity)
        }
        .background(
            GlowBackground(
                theme: theme,
                shape: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg,
                                        style: .continuous),
                intensity: 1.0)
        )
    }

    // MARK: Error row

    private func errorRow(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignTokens.Palette.failure)
            Text(error)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm,
                             style: .continuous)
                .fill(DesignTokens.Palette.failure.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm,
                             style: .continuous)
                .stroke(DesignTokens.Palette.failure.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: Credential card

    @ViewBuilder
    private var credentialCard: some View {
        let singleFields = provider.settingsFields().filter { !$0.isMultiValue }
        if !singleFields.isEmpty {
            SettingsCard(title: "Credentials") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    ForEach(singleFields) { field in
                        credentialField(field)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func credentialField(_ field: SettingsField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(field.label)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.white.opacity(0.70))

            GlassTextField(
                placeholder: field.placeholder,
                text: binding(for: field),
                isSecret: field.isSecret,
                accent: theme.accent,
                isFocused: focusedKey == field.key
            )
            .focused($focusedKey, equals: field.key)

            if let hint = field.hint {
                Text(hint)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: Multi-value cards

    @ViewBuilder
    private var multiValueCards: some View {
        ForEach(provider.settingsFields().filter(\.isMultiValue)) { field in
            SettingsCard(title: field.label, footer: field.hint) {
                MultiValueFieldSection(field: field,
                                        rawValue: binding(for: field),
                                        accent: theme.accent)
            }
        }
    }

    // MARK: Actions card

    private var actionCard: some View {
        SettingsCard(title: nil) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                Button(action: saveAndRestart) {
                    actionRow(icon: "checkmark",
                              title: "Save",
                              trailing: saved ? AnyView(
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(DesignTokens.Palette.success))
                                              : nil)
                }
                .buttonStyle(.plain)

                Divider().overlay(DesignTokens.Palette.hairline)

                Button {
                    Task { await testConnection() }
                } label: {
                    actionRow(
                        icon: "network",
                        title: "Test Connection",
                        trailing: testTrailing)
                }
                .buttonStyle(.plain)
                .disabled(testing)
            }
        }
    }

    private var testTrailing: AnyView? {
        if testing {
            return AnyView(ProgressView().tint(.white))
        }
        switch testResult {
        case .success(let count):
            return AnyView(
                HStack(spacing: 4) {
                    Text("\(count)")
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Palette.success))
        case .failure:
            return AnyView(
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(DesignTokens.Palette.failure))
        case nil:
            return nil
        }
    }

    private func actionRow(icon: String, title: String, trailing: AnyView?) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(theme.accent)
                .frame(width: 22)
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            if let trailing { trailing }
        }
        .padding(.vertical, 4)
    }

    // MARK: Delete card

    private var deleteCard: some View {
        SettingsCard(title: nil) {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundStyle(DesignTokens.Palette.failure)
                        .frame(width: 22)
                    Text("Delete Integration")
                        .foregroundStyle(DesignTokens.Palette.failure)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Bindings & Persistence

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

// MARK: - SettingsCard (reusable glass container)

struct SettingsCard<Content: View>: View {
    let title: String?
    var footer: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 6)
            }

            content()
                .padding(DesignTokens.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md,
                                     style: .continuous)
                        .fill(DesignTokens.Palette.surface.opacity(0.65))
                )
                .liquidGlass(in: RoundedRectangle(
                    cornerRadius: DesignTokens.Radius.md,
                    style: .continuous))

            if let footer {
                Text(footer)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 6)
            }
        }
    }
}

// MARK: - GlassTextField

struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecret: Bool = false
    var accent: Color = .white
    var isFocused: Bool = false

    var body: some View {
        Group {
            if isSecret {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .font(.system(size: 15, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm,
                             style: .continuous)
                .fill(Color.white.opacity(isFocused ? 0.10 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm,
                             style: .continuous)
                .stroke(isFocused ? accent.opacity(0.70) : Color.white.opacity(0.10),
                        lineWidth: isFocused ? 1.5 : 1)
        )
        .animation(.easeOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Multi-value Field

private struct MultiValueFieldSection: View {
    let field: SettingsField
    @Binding var rawValue: String
    var accent: Color
    @State private var newItem: String = ""
    @FocusState private var inputFocused: Bool

    private var items: [String] {
        rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if !items.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(items, id: \.self) { item in
                        chip(for: item)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField(field.placeholder, text: $newItem)
                    .focused($inputFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(addItem)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm,
                                         style: .continuous)
                            .fill(Color.white.opacity(inputFocused ? 0.10 : 0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm,
                                         style: .continuous)
                            .stroke(inputFocused ? accent.opacity(0.7)
                                                 : Color.white.opacity(0.10),
                                    lineWidth: inputFocused ? 1.5 : 1)
                    )
                Button(action: addItem) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .liquidGlassCircle()
                }
                .buttonStyle(.plain)
                .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(newItem.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
        }
    }

    private func chip(for item: String) -> some View {
        HStack(spacing: 6) {
            Text(item)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
            Button {
                removeItem(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 5)
        .liquidGlassChip()
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

// MARK: - FlowLayout (simple wrap layout for chips)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
            totalWidth = max(totalWidth, x)
        }
        return CGSize(width: totalWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}

#Preview {
    NavigationStack {
        if let provider = ServiceRegistry.shared.provider(withID: "vercel") {
            ProviderSettingsView(provider: provider)
                .environmentObject(AppState())
        }
    }
    .preferredColorScheme(.dark)
}
