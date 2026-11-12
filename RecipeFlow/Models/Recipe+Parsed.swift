//
//  Recipe+Parsed.swift
//  RecipeFlow
//

import Foundation
import SwiftData

extension Recipe {
    static let untitledTitle = "Untitled recipe"

    /// Recipes saved before titles existed have an empty one.
    var displayTitle: String {
        title.isEmpty ? Recipe.untitledTitle : title
    }

    /// Parses `text` and saves the result as a new recipe with its ingredients and steps.
    @discardableResult
    static func create(from text: String, in context: ModelContext) -> Recipe {
        let parsed = RecipeParser.parse(text)
        let recipe = Recipe(title: parsed.title ?? untitledTitle, rawText: text)
        // Insert first: SwiftData crashes if an un-inserted model touches a to-many relationship.
        context.insert(recipe)
        recipe.ignoredLines = parsed.ignoredLines
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
