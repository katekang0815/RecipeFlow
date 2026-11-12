//
//  SourceLinkEditor.swift
//  RecipeFlow
//

import SwiftUI

/// Add or change a recipe's source link: paste it, or take a photo of it, then Save.
/// There is no library option; the photo is taken, cropped, and read on the spot.
struct SourceLinkEditor: View {
    /// The saved link when editing, nil when adding.
    let current: String?
    var onSave: (String) -> Void
    var onRemove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var message: String?
    @State private var isScanning = false
    @State private var showCamera = false
    @State private var showCameraDenied = false
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

                if CameraPicker.isAvailable {
                    Button {
                        CameraAccess.request(granted: { showCamera = true }, denied: { showCameraDenied = true })
                    } label: {
                        Group {
                            if isScanning {
                                ProgressView().tint(Theme.ink)
                            } else {
                                Label("Take photo of the link", systemImage: "camera")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(isScanning)
                    .accessibilityIdentifier("takeLinkPhotoButton")
                }

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
            .fullScreenCover(isPresented: $showCamera) {
                CameraFlow { image in
                    Task { await readLink(from: image) }
                }
            }
            .cameraDeniedAlert(isPresented: $showCameraDenied)
        }
        .tint(Theme.ink)
        .presentationDetents([.large])
    }

    private var invalidMessage: String? {
        isTyping && link == nil ? "That doesn't look like a web link." : nil
    }

    /// Reads the cropped photo and puts the first web link found into the field,
    /// where the user can check it before saving.
    private func readLink(from image: UIImage) async {
        isScanning = true
        message = nil
        defer { isScanning = false }

        do {
            let recognized = try await TextRecognizer.recognize(in: image)
            if let found = SourceLink.firstLink(in: recognized) {
                text = found.absoluteString
                message = "Check the link, then tap Save."
            } else {
                message = "No link found in the photo. Crop closer to the address and try again."
            }
        } catch {
            message = "Couldn't read that photo."
        }
    }
}

#Preview("Add") {
    SourceLinkEditor(current: nil, onSave: { _ in }, onRemove: {})
}

#Preview("Edit") {
    SourceLinkEditor(current: "https://www.youtube.com/watch?v=nqsoMyxHTbc", onSave: { _ in }, onRemove: {})
}
