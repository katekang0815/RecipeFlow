//
//  Recipe+Editing.swift
//  RecipeFlow
//

import Foundation
import SwiftData

/// Turning a recipe's ingredients or steps back into text, so the user can edit them,
/// and saving the edited text in their place. The text uses the same format the parser reads,
/// so parsing it again gives back the same ingredients and steps.
extension Recipe {
    // MARK: Ingredients

    /// One ingredient per line. A group gets a "Name:" line above it and a blank line after it.
    var ingredientsText: String {
        var lines: [String] = []
        var previousGroup: String?
        for (index, item) in sortedIngredients.enumerated() {
            if index > 0, item.group != previousGroup { lines.append("") }
            if item.group != nil, item.group != previousGroup || index == 0 {
                lines.append("\(item.group ?? ""):")
            }
            lines.append(Recipe.line(for: item))
            previousGroup = item.group
        }
        return lines.joined(separator: "\n")
    }

    /// "40 g bread flour", "salt to taste", "egg wash (1 egg yolk + milk)"
    private static func line(for item: Ingredient) -> String {
        let main: String
        if item.quantity.isEmpty {
            main = item.name
        } else if item.quantity.contains(where: \.isNumber) {
            main = [item.quantity, item.unit, item.name].filter { !$0.isEmpty }.joined(separator: " ")
        } else {
            main = "\(item.name) \(item.quantity)"  // "salt to taste", "소금 약간"
        }
        return item.prepNote.isEmpty ? main : "\(main) (\(item.prepNote))"
    }

    /// Replaces every ingredient with the parsed ones.
    func replaceIngredients(with parsed: [ParsedIngredient], in context: ModelContext) {
        // Take them out of the relationship first; deleted objects otherwise linger in it.
        let old = ingredients
        ingredients.removeAll()
        for item in old { context.delete(item) }

        for item in parsed {
            addIngredient(Ingredient(
                name: item.name, quantity: item.quantity, unit: item.unit,
                prepNote: item.note, group: item.group
            ))
        }
    }

    // MARK: Steps

    /// Numbered steps, each followed by its bullets: "1. Title. Rest of the line" then "• bullet".
    var stepsText: String {
        sortedSteps.enumerated().map { index, step in
            let detail = step.detail.components(separatedBy: "\n").filter { !$0.isEmpty }
            let bullets = detail.filter { $0.hasPrefix("• ") }
            let rest = detail.first.flatMap { $0.hasPrefix("• ") ? nil : $0 }

            var head = "\(index + 1). \(step.title)"
            if let rest { head += ". \(rest)" }
            return ([head] + bullets).joined(separator: "\n")
        }
        .joined(separator: "\n")
    }

    /// Replaces every step with the parsed ones, in order.
    func replaceSteps(with parsed: [ParsedStep], in context: ModelContext) {
        let old = steps
        steps.removeAll()
        for step in old { context.delete(step) }

        for step in parsed {
            insertStep(Step(title: step.title, detail: step.detail), at: steps.count)
        }
    }
}
