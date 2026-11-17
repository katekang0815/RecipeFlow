//
//  Recipe+Editing.swift
//  RecipeFlow
//

import Foundation
import SwiftData

/// Turning a recipe's ingredients or steps back into text, so the user can edit them,
/// and saving the edited text in their place.
extension Recipe {
    // MARK: Ingredients

    /// One ingredient per line.
    var ingredientsText: String {
        sortedIngredients.map(Recipe.line(for:)).joined(separator: "\n")
    }

    /// An ingredient as one line. New ingredients are just their line; older ones put it together
    /// from the amount, the unit and the name: "40 g bread flour", "salt to taste", "egg wash (1 egg yolk + milk)".
    static func line(for item: Ingredient) -> String {
        let main: String
        if item.quantity.isEmpty {
            main = item.name
        } else if item.quantity.contains(where: \.isNumber) {
            main = [item.quantity, item.unit, item.name].filter { !$0.isEmpty }.joined(separator: " ")
        } else {
            main = "\(item.name) \(item.quantity)"
        }
        return item.prepNote.isEmpty ? main : "\(main) (\(item.prepNote))"
    }

    /// Replaces every ingredient with one ingredient per line, kept as written.
    func replaceIngredients(withLines lines: [String], in context: ModelContext) {
        // Take them out of the relationship first; deleted objects otherwise linger in it.
        let old = ingredients
        ingredients.removeAll()
        for item in old { context.delete(item) }

        for line in lines { addIngredient(Ingredient(name: line)) }
    }

    // MARK: Steps

    /// Numbered steps, one line each. A step saved by an older version has its detail after the title.
    var stepsText: String {
        sortedSteps.enumerated().map { index, step in
            let head = "\(index + 1). \(step.title)"
            return step.detail.isEmpty ? head : head + " " + step.detail.replacingOccurrences(of: "\n", with: " ")
        }
        .joined(separator: "\n")
    }

    /// Replaces every step with the parsed ones, in order.
    func replaceSteps(with parsed: [ParsedStep], in context: ModelContext) {
        let old = steps
        steps.removeAll()
        for step in old { context.delete(step) }

        for step in parsed {
            insertStep(Step(title: step.title), at: steps.count)
        }
    }
}
