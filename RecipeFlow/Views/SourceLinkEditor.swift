//
//  SourceLinkEditor.swift
//  RecipeFlow
//

import SwiftUI

extension View {
    /// Add or change a recipe's source link in a pop-up over the screen: paste or type it, then tap the check.
    /// `current` is the saved link when editing, nil when adding.
    /// This is drawn here because the system's pop-up cannot have an icon in its field, or no buttons.
    func sourceLinkPopUp(
        isPresented: Binding<Bool>,
        current: String?,
        onSave: @escaping (String) -> Void,
        onRemove: @escaping () -> Void
    ) -> some View {
        overlay {
            ZStack {
                if isPresented.wrappedValue {
                    // A tap outside the pop-up closes it, and changes nothing.
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                        .onTapGesture { isPresented.wrappedValue = false }
                        .accessibilityElement()
                        .accessibilityLabel("Close")
                        .accessibilityIdentifier("sourceLinkBackdrop")
                    SourceLinkPopUp(
                        current: current,
                        onSave: {
                            onSave($0)
                            isPresented.wrappedValue = false
                        },
                        onRemove: {
                            onRemove()
                            isPresented.wrappedValue = false
                        }
                    )
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: isPresented.wrappedValue)
        }
    }
}

private struct SourceLinkPopUp: View {
    let current: String?
    var onSave: (String) -> Void
    var onRemove: () -> Void

    @State private var text: String
    /// A new link is typed straight away. A saved one is shown with the edit icon until it is tapped.
    @State private var isEditing: Bool
    @State private var wasInvalid = false
    @FocusState private var isFocused: Bool

    init(current: String?, onSave: @escaping (String) -> Void, onRemove: @escaping () -> Void) {
        self.current = current
        self.onSave = onSave
        self.onRemove = onRemove
        _text = State(initialValue: current ?? "")
        _isEditing = State(initialValue: current == nil)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(current == nil ? "Add source link" : "Edit source link")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink)

            HStack(spacing: 4) {
                TextField("", text: $text, prompt: Text("Paste a link").foregroundStyle(Theme.ink.opacity(0.4)))
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(save)
                    .focused($isFocused)
                    .foregroundStyle(Theme.ink)
                    .tint(Theme.ink)
                    .accessibilityIdentifier("sourceLinkField")

                if isEditing {
                    icon("checkmark", id: "saveSourceLinkButton", label: "Save", action: save)
                } else {
                    icon("pencil", id: "changeSourceLinkButton", label: "Edit") { isFocused = true }
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 4)
            .frame(height: 48)
            .background(Capsule().fill(Theme.ink.opacity(0.08)))

            if wasInvalid {
                Text("That doesn't look like a web link.")
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.7))
            }

            if current != nil {
                Button("Remove link", role: .destructive, action: onRemove)
                    .accessibilityIdentifier("removeSourceLinkButton")
            }
        }
        .padding(20)
        .frame(maxWidth: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32))
        .shadow(color: .black.opacity(0.15), radius: 24, y: 10)
        .padding(.horizontal, 24)
        .accessibilityAddTraits(.isModal)
        .onChange(of: isFocused) { _, focused in
            if focused { isEditing = true }
        }
        .onChange(of: text) { wasInvalid = false }
        .onAppear {
            // A moment later, so the field is on screen to take the keyboard.
            if current == nil { DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { isFocused = true } }
        }
    }

    /// The icon at the end of the field.
    private func icon(_ name: String, id: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private func save() {
        if let link = SourceLink.url(from: text) {
            onSave(link.absoluteString)
        } else {
            wasInvalid = true
        }
    }
}
