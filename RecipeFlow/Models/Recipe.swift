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
        ingredient.sortIndex = ingredients.count
        ingredients.append(ingredient)
    }

    func insertStep(_ step: Step, at index: Int) {
        var ordered = sortedSteps
        ordered.insert(step, at: min(max(index, 0), ordered.count))
        steps.append(step)
        renumber(ordered)
    }

    func deleteSteps(at offsets: IndexSet, in context: ModelContext) {
        let ordered = sortedSteps
        for offset in offsets { context.delete(ordered[offset]) }
        renumber(ordered.enumerated().filter { !offsets.contains($0.offset) }.map(\.element))
    }

    func moveSteps(from source: IndexSet, to destination: Int) {
        var ordered = sortedSteps
        ordered.move(fromOffsets: source, toOffset: destination)
        renumber(ordered)
    }

    private func renumber(_ ordered: [Step]) {
        for (index, step) in ordered.enumerated() { step.sortIndex = index }
    }
}
