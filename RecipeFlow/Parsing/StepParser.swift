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
/// A circle that was read as ® © or @ also starts a step; its number is lost, but the order is not.
/// A number may also sit alone on its line, as a number in a circle does when a photo is read:
/// the next line is then the step. Lines after a numbered line belong to its step.
/// Nothing else is looked for: no headers, bullets, ingredients or notes.
enum StepParser {
    static func parse(_ text: String) -> [ParsedStep] {
        stepLines(in: text).map(makeStep)
    }

    /// The text with its steps numbered one after another from `first`, whatever numbers it had.
    /// Each step's lines are kept as written; only the number in front of the step is replaced.
    /// Text with no number anywhere is split at the end of each sentence instead, see `bySentence`.
    static func renumbered(_ text: String, from first: Int) -> String {
        let steps = stepLines(in: text)
        guard !steps.isEmpty else { return bySentence(text, from: first) }
        return steps.enumerated().map { index, lines in
            (["\(first + index). \(lines[0])"] + lines.dropFirst()).joined(separator: "\n")
        }
        .joined(separator: "\n")
    }

    /// Text that has no number anywhere, as from a photo whose numbers were lost: one step per sentence,
    /// numbered from `first`. A step runs on to the line that ends a sentence, and a line in brackets
    /// stays with the step above it. A bullet in front of a step is dropped.
    static func bySentence(_ text: String, from first: Int) -> String {
        var steps: [String] = []
        var open = false  // the last step has not reached the end of its sentence
        for line in normalizedLines(text) where !line.isEmpty {
            if let last = steps.indices.last, open {
                steps[last] += " " + line
            } else if let last = steps.indices.last, line.hasPrefix("(") || line.hasPrefix("（") {
                steps[last] += "\n" + line
            } else {
                steps.append(line.replacing(/^[•·●○▪◦*\-–—]\s*/, with: ""))
            }
            open = !endsSentence(steps[steps.count - 1])
        }
        return steps.enumerated().map { "\(first + $0.offset). \($0.element)" }.joined(separator: "\n")
    }

    /// A full stop, even when a closing bracket or quote follows it; Korean sentences may end in 다 or 요.
    private static func endsSentence(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: ")）\"”’ "))
        guard let last = trimmed.last else { return false }
        return ".!?。！？다요".contains(last)
    }

    /// Each step as its lines, the number taken off the first.
    private static func stepLines(in text: String) -> [[String]] {
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
        return steps
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
        // A circle the text reader could not read as a number: it comes out as ® © @, or a circled letter
        if let first = line.first, isCircleMark(first) {
            return Marker(number: nil, rest: String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
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

    /// What the text reader makes of a circled number it cannot read (a circled 17 often comes out as ®),
    /// and circled letters: Ⓐ ⓑ ⒜. The number is lost, so these only mark where a step starts.
    static func isCircleMark(_ character: Character) -> Bool {
        if "®©@".contains(character) { return true }
        guard character.unicodeScalars.count == 1, let value = character.unicodeScalars.first?.value else { return false }
        return (0x24B6...0x24E9).contains(value) || (0x249C...0x24B5).contains(value)
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
