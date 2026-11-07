//
//  TextRecognizer.swift
//  RecipeFlow
//

import UIKit
import Vision

private extension CGImagePropertyOrientation {
    /// Photos from the camera carry an orientation; Vision needs it to read them upright.
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// Reads text out of an image with Apple's on-device Vision OCR.
enum TextRecognizer {
    enum Failure: Error {
        case unreadableImage
    }

    /// Returns the recognized lines joined with newlines, in reading order.
    /// Returns an empty string when the image contains no text.
    static func recognize(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw Failure.unreadableImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // Vision reads only English unless told otherwise. Let it detect the
            // language, and prefer Korean and English when it is unsure.
            request.recognitionLanguages = ["ko-KR", "en-US"]
            request.automaticallyDetectsLanguage = true

            DispatchQueue.global(qos: .userInitiated).async {
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
