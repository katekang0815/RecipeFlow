//
//  TextRecognizerTests.swift
//  RecipeFlowTests
//

import Testing
import UIKit
@testable import RecipeFlow

struct TextRecognizerTests {
    /// Draws black text on white, like a screenshot of a recipe.
    private func image(of lines: [String]) -> UIImage {
        let size = CGSize(width: 1200, height: 140 * CGFloat(lines.count) + 80)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 72),
                .foregroundColor: UIColor.black,
            ]
            for (index, line) in lines.enumerated() {
                line.draw(at: CGPoint(x: 40, y: 40 + 140 * CGFloat(index)), withAttributes: attributes)
            }
        }
    }

    @Test func readsTextFromAnImage() async throws {
        let text = try await TextRecognizer.recognize(in: image(of: ["Ingredients", "40g bread flour"]))
        #expect(text.contains("Ingredients"))
        #expect(text.contains("bread flour"))
    }

    @Test func keepsLinesInReadingOrder() async throws {
        let text = try await TextRecognizer.recognize(in: image(of: ["First step", "Second step"]))
        let first = try #require(text.range(of: "First"))
        let second = try #require(text.range(of: "Second"))
        #expect(first.lowerBound < second.lowerBound)
    }

    @Test func blankImageGivesEmptyText() async throws {
        let text = try await TextRecognizer.recognize(in: image(of: []))
        #expect(text.isEmpty)
    }
}
