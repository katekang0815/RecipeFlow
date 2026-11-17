//
//  StepParser.swift
//  RecipeFlow
//

import Foundation

struct ParsedStep: Equatable {
    /// First sentence of the first line.
    var title: String
    /// The rest of the first line, then every following line up to the next number, one per line.
    var detail: String
}

/// Splits text that is known to be steps into one step per number.
///
/// A step starts at a line that begins with a number, in any of these styles:
/// 1  1.  1)  (1)  ①  ⒈  ❶  ➊  ⓫  ㉑  ㊱  I  II  III  a  b  c (with a . or ) after a letter).
/// A number may also sit alone on its line, as a number in a circle does when a photo is read:
/// the next line is then the step. Lines after a numbered line belong to its step.
/// Nothing else is looked for: no headers, bullets, ingredients or notes.
enum StepParser {
    static func parse(_ text: String) -> [ParsedStep] {
        var steps: [[String]] = []
        var previous = 0  // the last number seen, for numbers that have no punctuation
        var numberAlone = false  // the last line was just a number, so the next line is its step

        for line in normalizedLines(text) where !line.isEmpty {
            if let marker = marker(in: line, after: previous) {
                if let number = marker.number { previous = number }
                if marker.rest.isEmpty {
                    numberAlone = true
                } else {
                    numberAlone = false
                    steps.append([marker.rest])
                }
            } else if numberAlone {
                numberAlone = false
                steps.append([line])
            } else if !steps.isEmpty {
                steps[steps.count - 1].append(line)
            }
        }
        return steps.map(makeStep)
    }

    // MARK: Lines

    private static func normalizedLines(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { line in
                String(asciiDigits(line))
                    .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\u{00A0}" })
                    .joined(separator: " ")
            }
    }

    /// Full-width digits and punctuation as ASCII: "１．" is "1.".
    private static func asciiDigits(_ line: String) -> String {
        String(line.unicodeScalars.map { scalar -> Character in
            switch scalar.value {
            case 0xFF10...0xFF19: Character(UnicodeScalar(scalar.value - 0xFF10 + 0x30)!)
            case 0xFF0E: "."
            case 0xFF08: "("
            case 0xFF09: ")"
            default: Character(scalar)
            }
        })
    }

    // MARK: Numbers

    struct Marker {
        /// The value of a digit or circled number; nil for letters and Roman numerals.
        var number: Int?
        /// What follows the number on its line.
        var rest: String
    }

    static func marker(in line: String, after previous: Int) -> Marker? {
        // ① ⑴ ⒈ ❶ ➊ ⓫ ㉑ ㊱
        if let first = line.first, let number = circledValue(first) {
            return Marker(number: number, rest: String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
        }
        // (1) (a) (iv)
        if let match = line.wholeMatch(of: /\((\d{1,2}|[A-Za-z]|[IVXivx]{1,4})\)\s*(.*)/) {
            return Marker(number: Int(match.1), rest: String(match.2))
        }
        // 1. 1) 1] 1: 1、 — but not 1.5 or 1:30
        if let match = line.wholeMatch(of: /(\d{1,2})\s*[.)\]:、](?!\d)\s*(.*)/) {
            return Marker(number: Int(match.1), rest: String(match.2))
        }
        // A number on its own line (a number in a circle, read from a photo)
        if let match = line.wholeMatch(of: /\d{1,3}/), let number = Int(match.0), number == previous + 1 || number == 1 {
            return Marker(number: number, rest: "")
        }
        // 6 Rest the dough: with no punctuation only the next number counts, so "30 grams" stays text
        if let match = line.wholeMatch(of: /(\d{1,2})\s+(\S.*)/), let number = Int(match.1), number == previous + 1 || number == 1 {
            return Marker(number: number, rest: String(match.2))
        }
        // I. II) a. b) — a letter needs its . or ), or to be alone on its line
        if let match = line.wholeMatch(of: /([IVXivx]{1,4}|[A-Za-z])\s*[.)](?=\s|$)\s*(.*)/) {
            return Marker(number: nil, rest: String(match.2))
        }
        if line.wholeMatch(of: /[IVXivx]{1,4}|[A-Za-z]/) != nil {
            return Marker(number: nil, rest: "")
        }
        return nil
    }

    /// The number in a circled, parenthesized or dingbat digit: ① ⑵ ⒈ ❶ ➊ ⓫ ㉑ ㊱
    static func circledValue(_ character: Character) -> Int? {
        guard character.unicodeScalars.count == 1, let value = character.unicodeScalars.first?.value else { return nil }
        let ranges: [(ClosedRange<UInt32>, Int)] = [
            (0x2460...0x2473, 1),  // ① ... ⑳
            (0x2474...0x2487, 1),  // ⑴ ... ⒇
            (0x2488...0x249B, 1),  // ⒈ ... ⒛
            (0x24EB...0x24F4, 11),  // ⓫ ... ⓴
            (0x24F5...0x24FE, 1),  // ⓵ ... ⓾
            (0x2776...0x277F, 1),  // ❶ ... ❿
            (0x278A...0x2793, 1),  // ➊ ... ➓
            (0x3251...0x325F, 21),  // ㉑ ... ㉟
            (0x32B1...0x32BF, 36),  // ㊱ ... ㊿
        ]
        for (range, first) in ranges where range.contains(value) { return Int(value - range.lowerBound) + first }
        return nil
    }

    // MARK: A step

    private static func makeStep(_ lines: [String]) -> ParsedStep {
        var step = splitFirstSentence(lines[0])
        step.detail = ([step.detail] + lines.dropFirst()).filter { !$0.isEmpty }.joined(separator: "\n")
        return step
    }

    /// First sentence becomes the title, the rest the detail. A period inside a number ("1.5") is not a break.
    private static func splitFirstSentence(_ text: String) -> ParsedStep {
        if let end = text.range(of: #"[.!?。](?=\s|$)"#, options: .regularExpression) {
            let title = String(text[..<end.lowerBound]).trimmingCharacters(in: .whitespaces)
            let detail = String(text[end.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !title.isEmpty { return ParsedStep(title: title, detail: detail) }
        }
        return ParsedStep(title: text, detail: "")
    }
}
