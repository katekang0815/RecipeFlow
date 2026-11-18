//
//  StepParser.swift
//  RecipeFlow
//

import Foundation

struct ParsedStep: Equatable {
    /// The whole step as one paragraph: its lines joined with spaces, symbols and all.
    var title: String
}

/// Splits text that is known to be steps into one step per number.
///
/// A step starts at a line that begins with a number, in any of these styles:
/// 1  1.  1)  (1)  ①  ⒈  ❶  ➊  ⓫  ㉑  ㊱  I  II  III  a  b  c (with a . or ) after a letter).
/// A circle that was read as ® © or @ also starts a step; its number is lost, but the order is not.
/// A number may also sit alone on its line, as a number in a circle does when a photo is read:
/// the next line is then the step. Lines after a numbered line belong to its step, and a step is kept
/// as one paragraph: its lines joined with spaces, with every symbol the text reader returned.
/// A list of bullets or dashes (at least two lines, and no ordinary numbers in the text) counts too:
/// each line is a step. Nothing else is looked for: no headers, ingredients or notes.
enum StepParser {
    static func parse(_ text: String) -> [ParsedStep] {
        stepLines(in: text).map(makeStep)
    }

    /// The text with its steps numbered one after another from `first`, whatever numbers it had.
    /// Each step becomes one line: its own lines joined with spaces, with the number in front replaced.
    /// Text with no numbered step in it is returned as it is.
    static func renumbered(_ text: String, from first: Int) -> String {
        let steps = stepLines(in: text)
        guard !steps.isEmpty else { return text }
        return steps.enumerated().map { index, lines in
            "\(first + index). " + lines.joined(separator: " ")
        }
        .joined(separator: "\n")
    }

    /// Each step as its lines, the number taken off the first.
    private static func stepLines(in text: String) -> [[String]] {
        let lines = normalizedLines(text)
        var steps: [[String]] = []
        for (line, role) in zip(lines, roles(of: lines)) {
            switch role {
            case .start(let rest): steps.append([rest])
            case .afterNumber: steps.append([line])
            case .text: if !line.isEmpty, !steps.isEmpty { steps[steps.count - 1].append(line) }
            case .numberOnly: break
            }
        }
        return steps
    }

    /// What each line of a text is, for finding where steps start.
    enum Role: Equatable {
        /// A line that starts a step; `rest` is what follows its number.
        case start(rest: String)
        /// A number alone on its line: the step is the next line.
        case numberOnly
        /// The line after a number that was alone: the text of that step.
        case afterNumber
        /// Any other line, empty ones included: part of the step above, or left out before the first step.
        case text
    }

    /// The role of each of `lines`, which are already normalized (see `normalizedLines`).
    static func roles(of lines: [String]) -> [Role] {
        var previous = 0  // the last number seen, for numbers that have no punctuation
        var numberAlone = false  // the last line was just a number, so the next line is its step
        let circleList = isCircleList(lines)

        return lines.map { line in
            guard !line.isEmpty else { return .text }
            if let marker = marker(in: line, after: previous, circleList: circleList) {
                if let number = marker.number { previous = number }
                if marker.rest.isEmpty {
                    numberAlone = true
                    return .numberOnly
                }
                numberAlone = false
                return .start(rest: marker.rest)
            }
            if numberAlone {
                numberAlone = false
                return .afterNumber
            }
            return .text
        }
    }

    // MARK: Lines

    static func normalizedLines(_ text: String) -> [String] {
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

    static func marker(in line: String, after previous: Int, circleList: Bool = false) -> Marker? {
        // ① ⑴ ⒈ ❶ ➊ ⓫ ㉑ ㊱
        if let first = line.first, let number = circledValue(first) {
            return Marker(number: number, rest: String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
        }
        // A circle the text reader could not read as a number: it comes out as ® © @, or a circled letter
        if let first = line.first, isCircleMark(first) {
            return Marker(number: nil, rest: String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
        }
        if circleList {
            // A list of circled numbers, all read as something else: a bullet or star, or a single letter
            // in front of a capital ("G Cover with plastic wrap").
            if startsWithBullet(line) {
                return Marker(number: nil, rest: String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
            }
            if let match = line.wholeMatch(of: /[A-Za-z]\s+(\p{Lu}.*)/) {
                return Marker(number: nil, rest: String(match.1))
            }
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

    private static let bullets: Set<Character> = ["•", "·", "●", "○", "◦", "▪", "‣", "*"]
    private static let dashes: Set<Character> = ["-", "–", "—"]

    /// A bullet, or a dash with a space after it ("- Mix"; "-5°C" is not a list).
    private static func startsWithBullet(_ line: String) -> Bool {
        guard let first = line.first else { return false }
        if bullets.contains(first) { return true }
        return dashes.contains(first) && line.dropFirst().first?.isWhitespace == true
    }

    /// A photo of circled numbers whose circles were all read as other symbols: no line has an ordinary
    /// number (1. (1) a. I.), and at least two start with a circle, a symbol standing for one, or a bullet.
    /// Only then is a bullet or star the start of a step; next to ordinary numbers it is a line inside one.
    private static func isCircleList(_ lines: [String]) -> Bool {
        let hasNumbers = lines.contains { line in
            line.wholeMatch(of: /\((\d{1,2}|[A-Za-z]|[IVXivx]{1,4})\)\s*(.*)/) != nil
                || line.wholeMatch(of: /(\d{1,2})\s*[.)\]:、](?!\d)\s*(.*)/) != nil
                || line.wholeMatch(of: /\d{1,3}/) != nil
                || line.wholeMatch(of: /([IVXivx]{1,4}|[A-Za-z])\s*[.)](?=\s|$)\s*(.*)/) != nil
        }
        guard !hasNumbers else { return false }
        let circles = lines.filter { line in
            guard let first = line.first else { return false }
            return circledValue(first) != nil || isCircleMark(first) || startsWithBullet(line)
        }
        return circles.count >= 2
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
        ParsedStep(title: lines.joined(separator: " "))
    }
}
