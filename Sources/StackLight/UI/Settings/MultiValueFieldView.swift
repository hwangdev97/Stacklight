import SwiftUI
import StackLightCore

// MARK: - Multi-Value Field (add / remove tags)

struct MultiValueFieldView: View {
    let field: SettingsField
    @Binding var rawValue: String
    /// Optional per-entry error messages from the last Test/fetch — when
    /// non-empty, a red exclamation badge appears next to the matching row
    /// and `.help()` shows the full error on hover.
    var itemErrors: [String: String] = [:]
    @State private var newItem: String = ""

    private var items: [String] {
        rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(field.label)
                .font(.subheadline.weight(.medium))

            if let hint = field.hint {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Existing items
            if !items.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        if index > 0 {
                            Divider().padding(.leading, 12)
                        }
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(item)
                                        .font(.body.monospaced())
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    if let errorMessage = itemErrors[item] {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundStyle(.red)
                                            .help(errorMessage)
                                    }
                                }

                                if let errorMessage = itemErrors[item] {
                                    Text(errorMessage)
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .help(errorMessage)
                                }
                            }

                            Spacer()

                            Button {
                                removeItem(item)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                    }
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 0.5)
                )
            }

            // Add new item
            HStack(spacing: 8) {
                TextField("", text: $newItem, prompt: Text(field.placeholder))
                    .textFieldStyle(.plain)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 0.5)
                    )
                    .onSubmit { addItem() }

                Button {
                    addItem()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addItem() {
        let trimmed = newItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !items.contains(trimmed) else { newItem = ""; return }

        var current = items
        current.append(trimmed)
        rawValue = current.joined(separator: ", ")
        newItem = ""
    }

    private func removeItem(_ item: String) {
        var current = items
        current.removeAll { $0 == item }
        rawValue = current.joined(separator: ", ")
    }
}
