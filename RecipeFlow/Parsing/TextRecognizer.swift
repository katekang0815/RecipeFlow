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
        guard let (cgImage, orientation) = readable(image) else { throw Failure.unreadableImage }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let pieces = observations.compactMap { observation in
                    observation.topCandidates(1).first.map { (text: $0.string, box: observation.boundingBox) }
                }
                continuation.resume(returning: correctedEndings(arrange(pieces)).joined(separator: "\n"))
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

    // MARK: Small images

    /// Text in a small image is easily misread, so a small image is enlarged first, up to three times.
    /// The photo's orientation is applied while drawing, so the result is upright.
    private static func readable(_ image: UIImage) -> (CGImage, CGImagePropertyOrientation)? {
        guard let cgImage = image.cgImage else { return nil }
        let longest = CGFloat(max(cgImage.width, cgImage.height))
        let target: CGFloat = 2000
        guard longest < target else { return (cgImage, CGImagePropertyOrientation(image.imageOrientation)) }

        let factor = min(3, target / longest)
        let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let enlarged = UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.interpolationQuality = .high
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return enlarged.cgImage.map { ($0, .up) }
    }

    // MARK: A misread Korean ending

    /// The text reader sometimes reads the Korean "요." at the end of a line as a digit, "8." or "2.", which
    /// then looks like a step number. A line that begins with a digit and a full stop and then an opening bracket,
    /// right after a line of Korean, is that "요." and is put back.
    static func correctedEndings(_ lines: [String]) -> [String] {
        var result: [String] = []
        for line in lines {
            if let previous = result.last, previous.last.map(isHangul) == true,
               let match = line.wholeMatch(of: /[0-9]{1,2}\.\s*([(（\[［].*)/) {
                result.append("요. " + match.1)
            } else {
                result.append(line)
            }
        }
        return result
    }

    private static func isHangul(_ character: Character) -> Bool {
        character.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) || (0x1100...0x11FF).contains($0.value) }
    }

    // MARK: Numbers beside their text

    /// A short number, letter or circled digit: what a step number looks like by itself.
    private static func isMarker(_ text: String) -> Bool {
        guard text.count <= 4 else { return false }
        if text.wholeMatch(of: /\(?(\d{1,3}|[IVXivx]{1,4}|[A-Za-z])[.)]?/) != nil { return true }
        guard text.count == 1, let first = text.first else { return false }
        return StepParser.circledValue(first) != nil || StepParser.isCircleMark(first)
    }

    /// The lines of text. A step number in a circle is a block of its own, and the reader tends to list
    /// all the numbers first and then all the texts ("1 2 3 4" then four paragraphs). So a number is
    /// put back in front of the text on its row, as "1. text", which says which step it belongs to.
    /// `box`es are Vision's: from 0 to 1, with the origin at the bottom left.
    static func arrange(_ pieces: [(text: String, box: CGRect)]) -> [String] {
        var numberFor: [Int: String] = [:]  // text piece -> the number found beside it
        var used = Set<Int>()  // number pieces that were put back beside their text

        for (index, piece) in pieces.enumerated() where isMarker(piece.text) {
            let number = piece.box
            let candidates = pieces.indices.filter { other in
                guard other != index, !isMarker(pieces[other].text), numberFor[other] == nil else { return false }
                let text = pieces[other].box
                let isRight = text.minX >= number.maxX - 0.01
                let sameRow = abs(number.midY - text.midY) <= max(text.height, number.height) * 0.75
                return isRight && sameRow
            }
            // The nearest one to the right, then the closest row.
            guard let match = candidates.min(by: {
                let a = pieces[$0].box, b = pieces[$1].box
                if abs(a.minX - b.minX) > 0.02 { return a.minX < b.minX }
                return abs(a.midY - number.midY) < abs(b.midY - number.midY)
            }) else { continue }
            numberFor[match] = piece.text
            used.insert(index)
        }

        return pieces.enumerated().compactMap { index, piece in
            if used.contains(index) { return nil }
            guard let number = numberFor[index] else { return piece.text }
            let isDigits = number.wholeMatch(of: /[0-9]{1,3}/) != nil
            let isLetter = number.wholeMatch(of: /[IVXivx]{1,4}|[A-Za-z]/) != nil
            // A plain number gets its full stop, so it counts whatever number comes before it.
            return (isDigits || isLetter) ? "\(number). \(piece.text)" : "\(number) \(piece.text)"
        }
    }
}
