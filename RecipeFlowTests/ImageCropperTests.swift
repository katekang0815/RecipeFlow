//
//  ImageCropperTests.swift
//  RecipeFlowTests
//

import Testing
import UIKit
@testable import RecipeFlow

struct ImageCropperTests {
    /// 100 x 200 pixels: left half red, right half blue.
    private func twoToneImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 100, height: 200), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 50, height: 200))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 50, y: 0, width: 50, height: 200))
        }
    }

    /// RGBA of the pixel at the middle of the image.
    private func centerPixel(of image: UIImage) -> [UInt8] {
        let cgImage = image.cgImage!
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(cgImage, in: CGRect(
            x: -CGFloat(cgImage.width / 2), y: -CGFloat(cgImage.height / 2),
            width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)
        ))
        return pixel
    }

    @Test func cropsToTheRequestedFraction() throws {
        let cropped = try #require(ImageCropper.crop(twoToneImage(), to: CGRect(x: 0.5, y: 0, width: 0.5, height: 1)))
        #expect(cropped.cgImage?.width == 50)
        #expect(cropped.cgImage?.height == 200)
        let pixel = centerPixel(of: cropped)
        #expect(pixel[2] > 200 && pixel[0] < 50, "the kept half should be blue")
    }

    @Test func cropsATopSlice() throws {
        let cropped = try #require(ImageCropper.crop(twoToneImage(), to: CGRect(x: 0, y: 0, width: 1, height: 0.25)))
        #expect(cropped.cgImage?.width == 100)
        #expect(cropped.cgImage?.height == 50)
    }

    @Test func fullRectKeepsTheWholeImage() throws {
        let cropped = try #require(ImageCropper.crop(twoToneImage(), to: CGRect(x: 0, y: 0, width: 1, height: 1)))
        #expect(cropped.cgImage?.width == 100)
        #expect(cropped.cgImage?.height == 200)
    }

    @Test func uprightBakesInTheOrientation() throws {
        // Pixels are 100 x 200, but the .right flag means it displays as 200 x 100.
        let rotated = UIImage(cgImage: try #require(twoToneImage().cgImage), scale: 1, orientation: .right)
        #expect(rotated.size == CGSize(width: 200, height: 100))

        let upright = ImageCropper.upright(rotated)
        #expect(upright.imageOrientation == .up)
        #expect(upright.cgImage?.width == 200)
        #expect(upright.cgImage?.height == 100)
    }

    @Test func emptyRectGivesNil() {
        #expect(ImageCropper.crop(twoToneImage(), to: CGRect(x: 0.5, y: 0.5, width: 0, height: 0)) == nil)
    }
}
