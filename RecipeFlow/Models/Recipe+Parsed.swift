//
//  Recipe+Parsed.swift
//  RecipeFlow
//

import Foundation
import SwiftData

extension Recipe {
    static let untitledTitle = "Untitled recipe"

    /// What lists show: an empty or blank title shows as "Untitled recipe".
    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Recipe.untitledTitle : title
    }

    /// Parses `text` and saves the result as a new recipe with its ingredients and steps.
    @discardableResult
    static func create(from text: String, in context: ModelContext) -> Recipe {
        let parsed = RecipeParser.parse(text)
        // No title in the text leaves it empty, so the title field can show a hint and be typed into.
        let recipe = Recipe(title: parsed.title ?? "", rawText: text)
        // Insert first: SwiftData crashes if an un-inserted model touches a to-many relationship.
        context.insert(recipe)
        recipe.note = parsed.note.joined(separator: "\n")

        for item in parsed.ingredients {
            recipe.addIngredient(Ingredient(
                name: item.name, quantity: item.quantity, unit: item.unit,
                prepNote: item.note, group: item.group
            ))
        }
        for step in parsed.steps {
            recipe.insertStep(Step(title: step.title, detail: step.detail), at: recipe.steps.count)
        }
        return recipe
    }
}
