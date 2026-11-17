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

    @Test func readsKoreanText() async throws {
        let text = try await TextRecognizer.recognize(in: image(of: ["재료", "밀가루 40g", "설탕 60g"]))
        #expect(text.contains("재료"))
        #expect(text.contains("밀가루"))
        #expect(text.contains("설탕"))
    }

    @Test func readsMixedKoreanAndEnglish() async throws {
        let text = try await TextRecognizer.recognize(in: image(of: ["1. 밀가루 and sugar를 섞는다"]))
        #expect(text.contains("밀가루"))
        #expect(text.contains("sugar"))
    }

    @Test func blankImageGivesEmptyText() async throws {
        let text = try await TextRecognizer.recognize(in: image(of: []))
        #expect(text.isEmpty)
    }
}

/// A step number in a circle is a block of its own beside its text.
struct NumbersBesideTextTests {
    /// A piece of text at a place on the page; y counts from the top, like a page.
    private func piece(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat = 0.6, height: CGFloat = 0.03) -> (text: String, box: CGRect) {
        (text, CGRect(x: x, y: 1 - y - height, width: width, height: height))
    }

    @Test func numbersListedFirstAreMovedBesideTheirText() {
        // The reader returns the numbers as one column, then the texts.
        let pieces = [
            piece("1", x: 0.05, y: 0.10, width: 0.05), piece("2", x: 0.05, y: 0.20, width: 0.05), piece("3", x: 0.05, y: 0.30, width: 0.05),
            piece("Prep the ribs: Peel the membrane.", x: 0.15, y: 0.10),
            piece("makes them softer.", x: 0.15, y: 0.14),
            piece("Parboil: Put the ribs in a pot.", x: 0.15, y: 0.20),
            piece("Skim and simmer: Once boiling.", x: 0.15, y: 0.30),
        ]
        #expect(TextRecognizer.arrange(pieces) == [
            "1. Prep the ribs: Peel the membrane.",
            "makes them softer.",
            "2. Parboil: Put the ribs in a pot.",
            "3. Skim and simmer: Once boiling.",
        ])
    }

    @Test func aNumberWithNoTextBesideItStaysWhereItIs() {
        let pieces = [piece("7", x: 0.05, y: 0.10, width: 0.05), piece("Braise: Return the ribs.", x: 0.15, y: 0.40)]
        #expect(TextRecognizer.arrange(pieces) == ["7", "Braise: Return the ribs."])
    }

    @Test func aNumberIsOnlyPutBesideTextToItsRight() {
        let pieces = [piece("2", x: 0.80, y: 0.10, width: 0.05), piece("Left text on the same row.", x: 0.05, y: 0.10, width: 0.5)]
        #expect(TextRecognizer.arrange(pieces) == ["2", "Left text on the same row."])
    }

    @Test func textThatIsNotANumberIsLeftAlone() {
        let pieces = [piece("Ingredients", x: 0.05, y: 0.10), piece("40g bread flour", x: 0.05, y: 0.15)]
        #expect(TextRecognizer.arrange(pieces) == ["Ingredients", "40g bread flour"])
    }

    @Test func circledNumbersKeepTheirGlyph() {
        let pieces = [piece("②", x: 0.05, y: 0.10, width: 0.05), piece("Heat the cream.", x: 0.15, y: 0.10)]
        #expect(TextRecognizer.arrange(pieces) == ["② Heat the cream."])
    }

    @Test func eachNumberTakesItsOwnRow() {
        let pieces = [
            piece("1", x: 0.05, y: 0.10, width: 0.05), piece("2", x: 0.05, y: 0.20, width: 0.05),
            piece("First.", x: 0.15, y: 0.10), piece("Second.", x: 0.15, y: 0.20),
        ]
        #expect(TextRecognizer.arrange(pieces) == ["1. First.", "2. Second."])
    }
}

/// "요." at the end of a Korean line, read as a digit.
struct MisreadEndingTests {
    @Test func aDigitAndBracketAfterKoreanIsPutBackAsTheEnding() {
        let lines = ["유자청 (선택)을 넣어 향을 더하세", "8. (5 minutes • 05:00 )", "4 가루에 기름 비비기: 섞습니다."]
        #expect(TextRecognizer.correctedEndings(lines) == ["유자청 (선택)을 넣어 향을 더하세", "요. (5 minutes • 05:00 )", "4 가루에 기름 비비기: 섞습니다."])
        #expect(TextRecognizer.correctedEndings(["향을 더하세", "2. （5 minutes ▶ 05:00）"]) == ["향을 더하세", "요. （5 minutes ▶ 05:00）"])
    }

    @Test func aRealNumberedStepIsLeftAlone() {
        // No bracket right after the number, or no Korean line above it.
        #expect(TextRecognizer.correctedEndings(["향을 더하세", "8. 가루에 기름 비비기"]) == ["향을 더하세", "8. 가루에 기름 비비기"])
        #expect(TextRecognizer.correctedEndings(["Mix well.", "8. (optional) Add salt."]) == ["Mix well.", "8. (optional) Add salt."])
    }
}
