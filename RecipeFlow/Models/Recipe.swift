//
//  Recipe.swift
//  RecipeFlow
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Recipe {
    var title: String
    var rawText: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Ingredient.recipe)
    var ingredients: [Ingredient] = []

    @Relationship(deleteRule: .cascade, inverse: \Step.recipe)
    var steps: [Step] = []

    init(title: String = "", rawText: String = "", createdAt: Date = .now) {
        self.title = title
        self.rawText = rawText
        self.createdAt = createdAt
    }

    // SwiftData does not guarantee to-many relationship order, so views read these.
    var sortedIngredients: [Ingredient] {
        ingredients.sorted { $0.sortIndex < $1.sortIndex }
    }

    var sortedSteps: [Step] {
        steps.sorted { $0.sortIndex < $1.sortIndex }
    }

    func addIngredient(_ ingredient: Ingredient) {
        // max + 1 rather than count, so indexes stay unique after deletions
        ingredient.sortIndex = (ingredients.map(\.sortIndex).max() ?? -1) + 1
        ingredients.append(ingredient)
    }

    func deleteIngredients(at offsets: IndexSet, in context: ModelContext) {
        let ordered = sortedIngredients
        let removed = offsets.map { ordered[$0] }
        ingredients.removeAll { item in removed.contains { $0 === item } }
        for item in removed { context.delete(item) }
    }

    func insertStep(_ step: Step, at index: Int) {
        var ordered = sortedSteps
        ordered.insert(step, at: min(max(index, 0), ordered.count))
        steps.append(step)
        renumber(ordered)
    }

    func deleteSteps(at offsets: IndexSet, in context: ModelContext) {
        let ordered = sortedSteps
        let removed = offsets.map { ordered[$0] }
        // Deleting from the context alone leaves the steps in `steps` until SwiftData
        // processes pending changes, so drop them here too.
        steps.removeAll { step in removed.contains { $0 === step } }
        for step in removed { context.delete(step) }
        renumber(ordered.enumerated().filter { !offsets.contains($0.offset) }.map(\.element))
    }

    func moveSteps(from source: IndexSet, to destination: Int) {
        var ordered = sortedSteps
        ordered.move(fromOffsets: source, toOffset: destination)
        renumber(ordered)
    }

    /// Deletes the recipe and its children explicitly; the `.cascade` rule did not remove
    /// children in an in-memory test store, so we don't rely on it alone.
    func delete(from context: ModelContext) {
        for ingredient in ingredients { context.delete(ingredient) }
        for step in steps { context.delete(step) }
        context.delete(self)
    }

    private func renumber(_ ordered: [Step]) {
        for (index, step) in ordered.enumerated() { step.sortIndex = index }
    }
}
