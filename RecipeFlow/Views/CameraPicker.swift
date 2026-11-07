//
//  CameraPicker.swift
//  RecipeFlow
//

import SwiftUI
import UIKit

/// Presents the system camera. Reports the photo, or a cancel; the caller decides
/// what happens next (crop, dismiss).
struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

/// Camera, then crop. Retake goes back to the camera; Use photo hands the cropped image on.
struct CameraFlow: View {
    var onFinish: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var captured: UIImage?

    var body: some View {
        if let captured {
            CropView(
                image: captured,
                onDone: { image in
                    onFinish(image)
                    dismiss()
                },
                onRetake: { self.captured = nil }
            )
        } else {
            CameraPicker(
                onCapture: { captured = ImageCropper.upright($0) },
                onCancel: { dismiss() }
            )
            .ignoresSafeArea()
        }
    }
}
