//
//  PasteView.swift
//  RecipeFlow
//

import SwiftUI
import PhotosUI
import AVFoundation

struct PasteView: View {
    var onCreate: (String) -> Void

    @State private var text = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var showCameraDenied = false
    @State private var isScanning = false
    @State private var scanMessage: String?
    @State private var checkMessage: String?
    @State private var warning = ""
    @State private var showWarning = false
    @FocusState private var isFocused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 16) {
            RecipeTextField(text: $text, identifier: "pasteTextEditor")
                .focused($isFocused)

            if let message = checkMessage ?? scanMessage {
                Text(message)
                    .accessibilityIdentifier("pasteMessage")
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.7))
            }

            Menu {
                if CameraPicker.isAvailable {
                    Button { requestCamera() } label: {
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
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink, lineWidth: 2))
            }
            .disabled(isScanning)
            .accessibilityIdentifier("addPhotoButton")

            Button { create() } label: {
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
        .onChange(of: text) { checkMessage = nil }
        .alert("Check your recipe", isPresented: $showWarning) {
            Button("Create anyway") { onCreate(trimmed) }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text(warning)
        }
        .alert("Camera access is off", isPresented: $showCameraDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow camera access in Settings to take a photo of a recipe.")
        }
    }

    /// Only organized recipes get through. Text with no recipe in it is turned away,
    /// and a partial recipe asks first.
    private func create() {
        switch RecipeChecker.check(text: trimmed) {
        case .ready:
            onCreate(trimmed)
        case .partial(let issue):
            warning = issue.message
            showWarning = true
        case .rejected:
            checkMessage = RecipeCheck.rejectedMessage
        }
    }

    /// iOS asks for permission the first time; after a "no" the user has to use Settings.
    private func requestCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { showCamera = true } else { showCameraDenied = true }
                }
            }
        default:
            showCameraDenied = true
        }
    }

    private func scan(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            scanMessage = "Couldn't open that photo."
            return
        }
        await scan(image)
    }

    /// Runs OCR on a photo and appends the result to the text field,
    /// so the user can fix any misread characters before creating the recipe.
    private func scan(_ image: UIImage) async {
        isScanning = true
        scanMessage = nil
        defer { isScanning = false }

        do {
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
