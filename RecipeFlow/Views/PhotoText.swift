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

}

extension View {
    /// Lets a button elsewhere offer "Take photo" and "Choose from library" in a dialog.
    /// A photo is cropped, read, and reported to `onOutcome`.
    func photoTextSource(isChoosing: Binding<Bool>, onOutcome: @escaping (PhotoText.Outcome) -> Void) -> some View {
        photoSource(title: "Add a photo", isChoosing: isChoosing) { image in
            Task {
                if let image { onOutcome(await PhotoText.read(image)) }
                else { onOutcome(.problem("Couldn't open that photo.")) }
            }
        }
    }

    /// Offers "Take photo" and "Choose from library" in a dialog under `title`. A camera photo is
    /// cropped first. `onImage` gets the picture, or nil when a library photo could not be opened.
    func photoSource(title: String, isChoosing: Binding<Bool>, onImage: @escaping (UIImage?) -> Void) -> some View {
        modifier(PhotoSource(title: title, isChoosing: isChoosing, onImage: onImage))
    }
}

private struct PhotoSource: ViewModifier {
    var title: String
    @Binding var isChoosing: Bool
    var onImage: (UIImage?) -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var showCameraDenied = false

    /// UI tests cannot drive the system photo picker, so with this launch argument
    /// "Choose from library" hands over a made-up picture.
    private static let fakePhoto = ProcessInfo.processInfo.arguments.contains("-fakePhoto")

    func body(content: Content) -> some View {
        content
            .confirmationDialog(title, isPresented: $isChoosing, titleVisibility: .visible) {
                if CameraPicker.isAvailable {
                    Button("Take photo") {
                        CameraAccess.request(granted: { showCamera = true }, denied: { showCameraDenied = true })
                    }
                }
                Button("Choose from library") {
                    if Self.fakePhoto { onImage(Self.madeUpPhoto()) } else { showLibrary = true }
                }
            }
            .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                pickerItem = nil
                Task {
                    let data = try? await item.loadTransferable(type: Data.self)
                    onImage(data.flatMap(UIImage.init(data:)))
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraFlow { image in onImage(image) }
            }
            .cameraDeniedAlert(isPresented: $showCameraDenied)
    }

    private static func madeUpPhoto() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300)).image { context in
            UIColor.brown.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
        }
    }
}
