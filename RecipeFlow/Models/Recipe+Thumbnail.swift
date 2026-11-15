//
//  Recipe+Thumbnail.swift
//  RecipeFlow
//

import UIKit

extension Recipe {
    /// The longest side a stored thumbnail keeps, in pixels: plenty for a card, small to store.
    static let thumbnailSide: CGFloat = 640

    /// A photo as JPEG data, scaled down and turned upright for a card.
    static func thumbnailData(from image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, thumbnailSide / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        // Drawing applies the photo's orientation, so the result is upright.
        let upright = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return upright.jpegData(compressionQuality: 0.8)
    }

    var thumbnailImage: UIImage? {
        thumbnail.flatMap(UIImage.init(data:))
    }
}
