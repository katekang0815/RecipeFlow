//
//  PasteView.swift
//  RecipeFlow
//

import SwiftUI
import PhotosUI

struct PasteView: View {
    var onCreate: (String) -> Void

    @State private var text = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var isScanning = false
    @State private var scanMessage: String?
    @FocusState private var isFocused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 16) {
            RecipeTextField(text: $text, identifier: "pasteTextEditor")
                .focused($isFocused)

            if let scanMessage {
                Text(scanMessage)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.7))
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Group {
                    if isScanning {
                        ProgressView().tint(Theme.ink)
                    } else {
                        Label("Add photo", systemImage: "photo")
                    }
                }
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink, lineWidth: 2))
            }
            .disabled(isScanning)
            .accessibilityIdentifier("addPhotoButton")

            Button { onCreate(trimmed) } label: {
                Text("Create recipe").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(trimmed.isEmpty)
        }
        .padding(16)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Paste recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .onAppear { isFocused = true }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await scan(item) }
        }
    }

    /// Runs OCR on the picked photo and appends the result to the text field,
    /// so the user can fix any misread characters before creating the recipe.
    private func scan(_ item: PhotosPickerItem) async {
        isScanning = true
        scanMessage = nil
        defer {
            isScanning = false
            pickerItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                scanMessage = "Couldn't open that photo."
                return
            }
            let recognized = try await TextRecognizer.recognize(in: image)
            if recognized.isEmpty {
                scanMessage = "No text found in that photo."
            } else {
                text = trimmed.isEmpty ? recognized : trimmed + "\n" + recognized
            }
        } catch {
            scanMessage = "Couldn't read that photo."
        }
    }
}

#Preview {
    NavigationStack { PasteView { _ in } }
}
