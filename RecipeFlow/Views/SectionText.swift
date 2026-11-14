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

    /// Shown when the text has nothing for this section.
    var emptyMessage: String {
        switch self {
        case .ingredients: "No ingredients found. Put each ingredient on its own line."
        case .steps: "No numbered steps found. Start each step with a number, like 1. 2. 3."
        case .notes: "Write a note."
        }
    }

    /// The hint inside an empty field that is being typed into.
    var typingHint: String {
        switch self {
        case .ingredients: "Type or paste ingredients, one per line"
        case .steps: "Type or paste steps, numbered 1. 2. 3."
        case .notes: "Type or paste a note"
        }
    }
}

/// What a section's text holds, and what saving it would do.
/// Only this section is taken from the text, and the status says what was left out.
/// Notes are kept as written, one line per note line, with no parsing.
enum SectionText {
    static func parse(_ section: RecipeSection, _ text: String) -> ParsedRecipe {
        switch section {
        case .notes:
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return ParsedRecipe(note: lines)
        case .ingredients:
            return RecipeParser.parse(text, startingWithIngredients: true)
        case .steps:
            return RecipeParser.parse(text)
        }
    }

    /// `addition` placed after the text already in a card, on a new line. A photo of more steps or
    /// ingredients is added this way, so what was there is kept.
    static func appending(_ addition: String, to text: String) -> String {
        let current = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return current.isEmpty ? addition : current + "\n" + addition
    }

    /// How many items of this section the text holds.
    static func count(_ section: RecipeSection, _ parsed: ParsedRecipe) -> Int {
        switch section {
        case .ingredients: parsed.ingredients.count
        case .steps: parsed.steps.count
        case .notes: parsed.note.count
        }
    }

    /// A line for under the field while typing: what was found, or why nothing will be saved.
    static func status(_ section: RecipeSection, text: String, parsed: ParsedRecipe) -> String? {
        guard section != .notes else { return nil }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let found = count(section, parsed)
        guard found > 0 else { return section.emptyMessage }

        var message = "\(plural(found, String(section.noun.dropLast()))) found."
        let others = section == .steps
            ? (parsed.ingredients.count, "ingredient")
            : (parsed.steps.count, "step")
        if others.0 > 0 {
            message += " \(plural(others.0, others.1)) in this text will not be added."
        }
        return message
    }

    private static func plural(_ number: Int, _ singular: String) -> String {
        "\(number) \(singular)\(number == 1 ? "" : "s")"
    }
}
