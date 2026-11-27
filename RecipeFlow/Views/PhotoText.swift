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
    /// `onPaste` adds "Paste text" above the photo choices, for a section that is typed or pasted.
    func photoTextSource(
        isChoosing: Binding<Bool>,
        scan: Binding<Bool> = .constant(false),
        onPaste: (() -> Void)? = nil,
        onOutcome: @escaping (PhotoText.Outcome) -> Void
    ) -> some View {
        photoSource(title: "", isChoosing: isChoosing, scan: scan, onPaste: onPaste) { image in
            Task {
                if let image { onOutcome(await PhotoText.read(image)) }
                else { onOutcome(.problem("Couldn't open that photo.")) }
            }
        }
    }

    /// Offers "Take photo" and "Choose from library" in a dialog under `title`. A camera photo is
    /// cropped first. `onImage` gets the picture, or nil when a library photo could not be opened.
    /// With `cropsLibraryPhotos`, a photo from the library is cropped too, like a camera photo.
    func photoSource(
        title: String,
        isChoosing: Binding<Bool>,
        scan: Binding<Bool> = .constant(false),
        cropsLibraryPhotos: Bool = false,
        onPaste: (() -> Void)? = nil,
        onImage: @escaping (UIImage?) -> Void
    ) -> some View {
        modifier(PhotoSource(
            title: title, isChoosing: isChoosing, scan: scan, cropsLibraryPhotos: cropsLibraryPhotos, onPaste: onPaste, onImage: onImage
        ))
    }
}

private struct PhotoSource: ViewModifier {
    var title: String
    @Binding var isChoosing: Bool
    /// Set to true to go straight to the camera, as "Take photo" does, without the choices.
    @Binding var scan: Bool
    var cropsLibraryPhotos = false
    var onPaste: (() -> Void)?
    var onImage: (UIImage?) -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var showCameraDenied = false
    /// A library photo waiting to be cropped.
    @State private var photoToCrop: UIImage?
    /// What the chosen option does, once the choices have gone.
    @State private var pendingAction: (() -> Void)?

    /// UI tests cannot drive the system photo picker, so with this launch argument
    /// "Choose from library" hands over a made-up picture.
    private static let fakePhoto = ProcessInfo.processInfo.arguments.contains("-fakePhoto")

    func body(content: Content) -> some View {
        content
            // The choices are in a small sheet, each with an icon. What a choice does waits until the sheet has gone,
            // since the camera and the library are shown over the same screen.
            .sheet(isPresented: $isChoosing, onDismiss: {
                let action = pendingAction
                pendingAction = nil
                action?()
            }) {
                PhotoChoices(
                    title: title,
                    canPaste: onPaste != nil,
                    canTakePhoto: CameraPicker.isAvailable,
                    choose: { choice in
                        pendingAction = action(for: choice)
                        isChoosing = false
                    }
                )
            }
            .onChange(of: scan) { _, requested in
                guard requested else { return }
                scan = false
                // Without a camera (the Simulator) it falls back to the library.
                (action(for: CameraPicker.isAvailable ? .camera : .library))?()
            }
            .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                pickerItem = nil
                Task {
                    let data = try? await item.loadTransferable(type: Data.self)
                    libraryPhoto(data.flatMap(UIImage.init(data:)))
                }
            }
            .fullScreenCover(item: Binding(
                get: { photoToCrop.map(CropItem.init) },
                set: { if $0 == nil { photoToCrop = nil } }
            )) { item in
                CropView(
                    image: item.image,
                    onDone: { image in
                        photoToCrop = nil
                        onImage(image)
                    },
                    onRetake: {
                        photoToCrop = nil
                        showLibrary = true
                    },
                    retakeTitle: "Choose another"
                )
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraFlow { image in onImage(image) }
            }
            .cameraDeniedAlert(isPresented: $showCameraDenied)
    }

    private func action(for choice: PhotoChoice) -> (() -> Void)? {
        switch choice {
        case .cancel:
            return nil
        case .paste:
            return onPaste
        case .camera:
            return { CameraAccess.request(granted: { showCamera = true }, denied: { showCameraDenied = true }) }
        case .library:
            return { if Self.fakePhoto { libraryPhoto(Self.madeUpPhoto()) } else { showLibrary = true } }
        }
    }

    /// A photo from the library: cropped first when asked to, otherwise handed on as it is.
    private func libraryPhoto(_ image: UIImage?) {
        if cropsLibraryPhotos, let image {
            photoToCrop = ImageCropper.upright(image)
        } else {
            onImage(image)
        }
    }

    private struct CropItem: Identifiable {
        let image: UIImage
        let id = UUID()
    }

    private static func madeUpPhoto() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300)).image { context in
            UIColor.brown.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
        }
    }
}

enum PhotoChoice {
    case paste, camera, library, cancel
}

/// The options for adding a photo or text, in the bottom sheet.
private struct PhotoChoices: View {
    let title: String
    let canPaste: Bool
    let canTakePhoto: Bool
    let choose: (PhotoChoice) -> Void

    private var rows: [ChoiceSheet<PhotoChoice>.Row] {
        var rows: [ChoiceSheet<PhotoChoice>.Row] = []
        if canPaste { rows.append(.init(text: "Paste text", icon: "doc.on.clipboard", value: .paste)) }
        if canTakePhoto { rows.append(.init(text: "Take photo", icon: "camera", value: .camera)) }
        rows.append(.init(text: "Choose from library", icon: "photo.on.rectangle", value: .library))
        return rows
    }

    var body: some View {
        ChoiceSheet(title: title, rows: rows, choose: choose, cancel: { choose(.cancel) })
    }
}

/// A small sheet that pulls up from the bottom: one row for each option, with an icon, and Cancel.
struct ChoiceSheet<Value: Hashable>: View {
    struct Row {
        let text: String
        let icon: String
        let value: Value
        var color: Color = Theme.ink
    }

    let title: String
    let rows: [Row]
    let choose: (Value) -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 4)
            }
            ForEach(rows, id: \.value) { row($0) }
            Button("Cancel", action: cancel)
                .foregroundStyle(Theme.ink.opacity(0.7))
                .padding(.top, 2)
                .accessibilityIdentifier("cancelChoicesButton")
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.height(CGFloat(rows.count) * 62 + (title.isEmpty ? 110 : 150))])
        .presentationDragIndicator(.visible)
    }

    private func row(_ row: Row) -> some View {
        Button { choose(row.value) } label: {
            HStack(spacing: 14) {
                Image(systemName: row.icon)
                    .font(.system(size: 20))
                    .frame(width: 28)
                Text(row.text)
                    .font(.system(size: 17))
                Spacer(minLength: 0)
            }
            .foregroundStyle(row.color)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.field))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
