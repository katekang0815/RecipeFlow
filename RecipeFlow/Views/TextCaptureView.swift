//
//  TextCaptureView.swift
//  RecipeFlow
//

import SwiftUI
import PhotosUI

/// A large text field plus an Add photo menu (take a photo, or pick one). A photo is cropped,
/// read with OCR, and its text added to the end of the field, where it can still be corrected.
/// Used by the paste screen and by the screens that add or edit ingredients and steps.
/// A `trailing` button, such as Save, sits on the same line as Add photo.
struct TextCaptureView<Trailing: View>: View {
    @Binding var text: String
    var textIdentifier: String
    var autoFocus: Bool
    /// A message from the screen using this view, shown above the Add photo button.
    var message: String?
    var messageIdentifier: String
    private let trailing: Trailing

    @State private var pickerItem: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var showCameraDenied = false
    @State private var isScanning = false
    @State private var scanMessage: String?
    @FocusState private var isFocused: Bool

    init(
        text: Binding<String>,
        textIdentifier: String,
        autoFocus: Bool = false,
        message: String? = nil,
        messageIdentifier: String = "pasteMessage",
        @ViewBuilder trailing: () -> Trailing
    ) {
        _text = text
        self.textIdentifier = textIdentifier
        self.autoFocus = autoFocus
        self.message = message
        self.messageIdentifier = messageIdentifier
        self.trailing = trailing()
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 16) {
            RecipeTextField(text: $text, identifier: textIdentifier)
                .focused($isFocused)

            if let scanMessage {
                note(scanMessage)
            }
            if let message {
                note(message).accessibilityIdentifier(messageIdentifier)
            }

            HStack(spacing: 12) {
                addPhotoMenu
                trailing
            }
        }
        .onAppear { if autoFocus { isFocused = true } }
        .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await scan(item) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraFlow { image in
                Task { await scan(image) }
            }
        }
        .cameraDeniedAlert(isPresented: $showCameraDenied)
    }

    /// Sized like the primary button (same text size and padding), so the two line up side by side.
    private var addPhotoMenu: some View {
        Menu {
            if CameraPicker.isAvailable {
                Button {
                    CameraAccess.request(granted: { showCamera = true }, denied: { showCameraDenied = true })
                } label: {
                    Label("Take photo", systemImage: "camera")
                }
            }
            Button { showLibrary = true } label: {
                Label("Choose from library", systemImage: "photo")
            }
        } label: {
            Group {
                if isScanning {
                    ProgressView().tint(Theme.ink)
                } else {
                    Label("Add photo", systemImage: "photo")
                }
            }
            .font(.system(size: 22, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink, lineWidth: 2))
        }
        .disabled(isScanning)
        .accessibilityIdentifier("addPhotoButton")
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Theme.ink.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scan(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        isScanning = true
        await show(await PhotoText.read(item))
    }

    private func scan(_ image: UIImage) async {
        isScanning = true
        await show(await PhotoText.read(image))
    }

    /// Appends the recognized text to the field, so the user can fix any misread characters.
    private func show(_ outcome: PhotoText.Outcome) async {
        isScanning = false
        switch outcome {
        case .text(let recognized):
            scanMessage = nil
            text = trimmed.isEmpty ? recognized : trimmed + "\n" + recognized
        case .problem(let message):
            scanMessage = message
        }
    }
}

extension TextCaptureView where Trailing == EmptyView {
    /// With no trailing button, Add photo takes the full width.
    init(
        text: Binding<String>,
        textIdentifier: String,
        autoFocus: Bool = false,
        message: String? = nil,
        messageIdentifier: String = "pasteMessage"
    ) {
        self.init(
            text: text, textIdentifier: textIdentifier, autoFocus: autoFocus,
            message: message, messageIdentifier: messageIdentifier
        ) { EmptyView() }
    }
}
