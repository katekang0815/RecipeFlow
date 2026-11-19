//
//  SourceLinkEditor.swift
//  RecipeFlow
//

import SwiftUI

/// Add or change a recipe's source link: paste or type it, then Save.
struct SourceLinkEditor: View {
    /// The saved link when editing, nil when adding.
    let current: String?
    var onSave: (String) -> Void
    var onRemove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var message: String?
    @FocusState private var isFocused: Bool

    init(current: String?, onSave: @escaping (String) -> Void, onRemove: @escaping () -> Void) {
        self.current = current
        self.onSave = onSave
        self.onRemove = onRemove
        _text = State(initialValue: current ?? "")
    }

    private var link: URL? { SourceLink.url(from: text) }
    private var isTyping: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    TextField("Paste a link", text: $text)
                        .textFieldStyle(.plain)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .foregroundStyle(Theme.ink)
                        .tint(Theme.ink)
                        .accessibilityIdentifier("sourceLinkField")

                    PasteButton(payloadType: String.self) { strings in
                        if let pasted = strings.first { text = pasted }
                    }
                    .labelStyle(.iconOnly)
                    .tint(Theme.ink)
                    .accessibilityIdentifier("pasteLinkButton")
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))

                if let message = message ?? invalidMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Theme.ink.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("sourceLinkMessage")
                }

                Button {
                    if let link {
                        onSave(link.absoluteString)
                        dismiss()
                    }
                } label: {
                    Text("Save").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(link == nil)
                .accessibilityIdentifier("saveSourceLinkButton")

                if current != nil {
                    Button("Remove link", role: .destructive) {
                        onRemove()
                        dismiss()
                    }
                    .accessibilityIdentifier("removeSourceLinkButton")
                }

                Spacer()
            }
            .padding(16)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(current == nil ? "Add source link" : "Edit source link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: text) { message = nil }
        }
        .tint(Theme.ink)
        .presentationDetents([.large])
    }

    private var invalidMessage: String? {
        isTyping && link == nil ? "That doesn't look like a web link." : nil
    }
}

#Preview("Add") {
    SourceLinkEditor(current: nil, onSave: { _ in }, onRemove: {})
}

#Preview("Edit") {
    SourceLinkEditor(current: "https://www.youtube.com/watch?v=nqsoMyxHTbc", onSave: { _ in }, onRemove: {})
}
