//
//  SectionText.swift
//  RecipeFlow
//

import Foundation

/// The parts of a recipe that are edited in place, as text.
enum RecipeSection: String, Identifiable, Hashable {
    case ingredients
    case steps
    case notes

    var id: String { rawValue }

    var noun: String { rawValue }

    /// The hint inside an empty field that is being typed into.
    var typingHint: String {
        switch self {
        case .ingredients: "Type or paste ingredients, one per line"
        case .steps: "Type or paste steps, numbered 1. 2. 3."
        case .notes: "Type or paste a note"
        }
    }
}

/// What a card's text becomes. Ingredients and notes are kept as written, one line each, with no rules.
/// Only steps are split, at their numbers, see `StepParser`.
enum SectionText {
    /// The text's lines, trimmed. Empty lines between lines are kept, as the user made them to space the text;
    /// only the empty lines at the very start and end are dropped.
    static func lines(_ text: String) -> [String] {
        var lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        while lines.first?.isEmpty == true { lines.removeFirst() }
        while lines.last?.isEmpty == true { lines.removeLast() }
        return lines
    }

    static let onlyNumberedSteps = "Only numbered steps are valid"
    static let noStepsMessage = onlyNumberedSteps + ". Start each step with a number, like 1. 2. 3."

    /// A line for under the field while typing steps: what was found, or why nothing will be saved.
    static func stepsStatus(_ text: String) -> String? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let found = StepParser.parse(text).count
        guard found > 0 else { return noStepsMessage }
        return "\(found) step\(found == 1 ? "" : "s") found."
    }

    /// Steps from a photo added after the steps already in a card. They are numbered on from the last
    /// step, whatever numbers they came with, so adding the same 1, 2, 3 again makes 4, 5, 6.
    static func appendingSteps(_ addition: String, to text: String) -> String {
        let existing = StepParser.parse(text).count
        return appending(StepParser.renumbered(addition, from: existing + 1), to: text)
    }

    /// `addition` placed after the text already in a card, on a new line. A photo of more steps or
    /// ingredients is added this way, so what was there is kept.
    static func appending(_ addition: String, to text: String) -> String {
        let current = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return current.isEmpty ? addition : current + "\n" + addition
    }
}
