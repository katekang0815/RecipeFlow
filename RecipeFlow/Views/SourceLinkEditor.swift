//
//  SourceLinkEditor.swift
//  RecipeFlow
//

import SwiftUI

extension View {
    /// Add or change a recipe's source link in a pop-up: paste or type it, then Save.
    /// `current` is the saved link when editing, nil when adding.
    func sourceLinkPopUp(
        isPresented: Binding<Bool>,
        current: String?,
        onSave: @escaping (String) -> Void,
        onRemove: @escaping () -> Void
    ) -> some View {
        modifier(SourceLinkPopUp(isPresented: isPresented, current: current, onSave: onSave, onRemove: onRemove))
    }
}

private struct SourceLinkPopUp: ViewModifier {
    @Binding var isPresented: Bool
    let current: String?
    var onSave: (String) -> Void
    var onRemove: () -> Void

    @State private var text = ""
    /// What was typed was not a link, so the pop-up comes back saying so, with the text still in it.
    @State private var wasInvalid = false

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, shown in
                if shown, !wasInvalid { text = current ?? "" }
            }
            .alert(current == nil ? "Add source link" : "Edit source link", isPresented: $isPresented) {
                TextField("Paste a link", text: $text)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("sourceLinkField")
                Button("Save", action: save)
                if current != nil {
                    Button("Remove link", role: .destructive) {
                        wasInvalid = false
                        onRemove()
                    }
                }
                Button("Cancel", role: .cancel) { wasInvalid = false }
            } message: {
                if wasInvalid { Text("That doesn't look like a web link.") }
            }
    }

    private func save() {
        if let link = SourceLink.url(from: text) {
            wasInvalid = false
            onSave(link.absoluteString)
        } else {
            wasInvalid = true
            // The pop-up closes on any button, so it is shown again once it has gone.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                isPresented = true
            }
        }
    }
}
