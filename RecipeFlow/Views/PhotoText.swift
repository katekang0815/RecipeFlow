//
//  PhotoText.swift
//  RecipeFlow
//

import SwiftUI
import PhotosUI

/// Reads the text in a photo, or says why it could not.
enum PhotoText {
    enum Outcome: Equatable {
        case text(String)
        /// A message for the user.
        case problem(String)
    }

    static func read(_ image: UIImage) async -> Outcome {
        do {
            let recognized = try await TextRecognizer.recognize(in: image)
            return recognized.isEmpty ? .problem("No text found in that photo.") : .text(recognized)
        } catch {
            return .problem("Couldn't read that photo.")
        }
    }

    static func read(_ item: PhotosPickerItem) async -> Outcome {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return .problem("Couldn't open that photo.")
        }
        return await read(image)
    }
}

extension View {
    /// Lets a button elsewhere offer "Take photo" and "Choose from library" in a dialog.
    /// A photo is cropped, read, and reported to `onOutcome`.
    func photoTextSource(isChoosing: Binding<Bool>, onOutcome: @escaping (PhotoText.Outcome) -> Void) -> some View {
        modifier(PhotoTextSource(isChoosing: isChoosing, onOutcome: onOutcome))
    }
}

private struct PhotoTextSource: ViewModifier {
    @Binding var isChoosing: Bool
    var onOutcome: (PhotoText.Outcome) -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var showCameraDenied = false

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Add a photo", isPresented: $isChoosing, titleVisibility: .visible) {
                if CameraPicker.isAvailable {
                    Button("Take photo") {
                        CameraAccess.request(granted: { showCamera = true }, denied: { showCameraDenied = true })
                    }
                }
                Button("Choose from library") { showLibrary = true }
            }
            .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                pickerItem = nil
                Task { onOutcome(await PhotoText.read(item)) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraFlow { image in
                    Task { onOutcome(await PhotoText.read(image)) }
                }
            }
            .cameraDeniedAlert(isPresented: $showCameraDenied)
    }
}
