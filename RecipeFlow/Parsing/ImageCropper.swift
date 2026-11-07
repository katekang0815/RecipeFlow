//
//  ImageCropper.swift
//  RecipeFlow
//

import UIKit

enum ImageCropper {
    /// Redraws the image so its pixels are upright. Camera photos carry an
    /// orientation flag; cropping by pixels needs the real pixel layout.
    static func upright(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    /// Crops to `rect`, given as fractions (0...1) of the image's width and height
    /// with the origin at the top left. Returns nil if nothing is left to crop.
    static func crop(_ image: UIImage, to rect: CGRect) -> UIImage? {
        let upright = upright(image)
        guard let cgImage = upright.cgImage else { return nil }
        let pixelRect = CGRect(
            x: rect.minX * CGFloat(cgImage.width),
            y: rect.minY * CGFloat(cgImage.height),
            width: rect.width * CGFloat(cgImage.width),
            height: rect.height * CGFloat(cgImage.height)
        ).integral
        guard let cropped = cgImage.cropping(to: pixelRect) else { return nil }
        return UIImage(cgImage: cropped, scale: upright.scale, orientation: .up)
    }
}
