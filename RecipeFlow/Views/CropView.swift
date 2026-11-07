//
//  CropView.swift
//  RecipeFlow
//

import SwiftUI

/// Lets the user frame the recipe in a photo before it is read.
/// Drag a corner to resize the box, or drag inside it to move it.
struct CropView: View {
    let image: UIImage
    var onDone: (UIImage) -> Void
    var onRetake: () -> Void

    /// The crop box as fractions of the image, origin at the top left.
    @State private var rect = CGRect(x: 0, y: 0, width: 1, height: 1)

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { proxy in
                let fitted = fittedSize(in: proxy.size)
                CropOverlay(rect: $rect, image: image, size: fitted)
                    .frame(width: fitted.width, height: fitted.height)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }

            HStack(spacing: 12) {
                Button(action: onRetake) {
                    Text("Retake").frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("retakeButton")

                Button { onDone(ImageCropper.crop(image, to: rect) ?? image) } label: {
                    Text("Use photo").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("usePhotoButton")
            }
        }
        .padding(16)
        .background(Theme.background.ignoresSafeArea())
    }

    private func fittedSize(in container: CGSize) -> CGSize {
        guard image.size.width > 0, image.size.height > 0 else { return .zero }
        let scale = min(container.width / image.size.width, container.height / image.size.height)
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }
}

private struct CropOverlay: View {
    @Binding var rect: CGRect
    let image: UIImage
    let size: CGSize

    @State private var moveStart: CGRect?

    private let minSide: CGFloat = 0.1
    private let handleSize: CGFloat = 26

    private enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    /// The crop box in points, inside the fitted image.
    private var frame: CGRect {
        CGRect(
            x: rect.minX * size.width,
            y: rect.minY * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: image)
                .resizable()
                .frame(width: size.width, height: size.height)

            // Darken everything outside the crop box.
            Path { path in
                path.addRect(CGRect(origin: .zero, size: size))
                path.addRect(frame)
            }
            .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .shadow(color: .black.opacity(0.6), radius: 2)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .allowsHitTesting(false)

            Color.clear
                .frame(width: frame.width, height: frame.height)
                .contentShape(Rectangle())
                .position(x: frame.midX, y: frame.midY)
                .gesture(moveGesture)

            ForEach(Corner.allCases, id: \.self) { corner in
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
                    .frame(width: handleSize, height: handleSize)
                    .padding(9)
                    .contentShape(Rectangle())
                    .position(point(of: corner))
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("crop"))
                            .onChanged { resize(corner, to: $0.location) }
                    )
            }
        }
        .frame(width: size.width, height: size.height)
        .coordinateSpace(name: "crop")
        .accessibilityIdentifier("cropArea")
    }

    private func point(of corner: Corner) -> CGPoint {
        switch corner {
        case .topLeft: CGPoint(x: frame.minX, y: frame.minY)
        case .topRight: CGPoint(x: frame.maxX, y: frame.minY)
        case .bottomLeft: CGPoint(x: frame.minX, y: frame.maxY)
        case .bottomRight: CGPoint(x: frame.maxX, y: frame.maxY)
        }
    }

    private func resize(_ corner: Corner, to location: CGPoint) {
        guard size.width > 0, size.height > 0 else { return }
        let x = min(max(location.x / size.width, 0), 1)
        let y = min(max(location.y / size.height, 0), 1)
        var left = rect.minX, right = rect.maxX, top = rect.minY, bottom = rect.maxY

        switch corner {
        case .topLeft:
            left = min(x, right - minSide); top = min(y, bottom - minSide)
        case .topRight:
            right = max(x, left + minSide); top = min(y, bottom - minSide)
        case .bottomLeft:
            left = min(x, right - minSide); bottom = max(y, top + minSide)
        case .bottomRight:
            right = max(x, left + minSide); bottom = max(y, top + minSide)
        }
        rect = CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    private var moveGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard size.width > 0, size.height > 0 else { return }
                let start = moveStart ?? rect
                moveStart = start
                let x = start.minX + value.translation.width / size.width
                let y = start.minY + value.translation.height / size.height
                rect.origin = CGPoint(
                    x: min(max(x, 0), 1 - start.width),
                    y: min(max(y, 0), 1 - start.height)
                )
            }
            .onEnded { _ in moveStart = nil }
    }
}
