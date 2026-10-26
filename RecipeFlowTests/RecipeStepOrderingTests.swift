//
//  RecipeStepOrderingTests.swift
//  RecipeFlowTests
//

import Foundation
import Testing
import SwiftData
@testable import RecipeFlow

@MainActor
struct RecipeStepOrderingTests {

    // The container must outlive the context, so it is returned and held by each test.
    private func makeRecipe(_ titles: [String]) -> (Recipe, ModelContext, ModelContainer) {
        let container = PersistenceController.previewContainer(withSample: false)
        let context = container.mainContext
        let recipe = Recipe(title: "Test")
        context.insert(recipe)
        for (index, title) in titles.enumerated() {
            recipe.insertStep(Step(title: title), at: index)
        }
        return (recipe, context, container)
    }

    private func titles(_ recipe: Recipe) -> [String] { recipe.sortedSteps.map(\.title) }
    private func indexes(_ recipe: Recipe) -> [Int] { recipe.sortedSteps.map(\.sortIndex) }

    @Test func insertAppendsInOrder() {
        let (recipe, _, _) = makeRecipe(["A", "B", "C"])
        #expect(titles(recipe) == ["A", "B", "C"])
        #expect(indexes(recipe) == [0, 1, 2])
    }

    @Test func insertInMiddleRenumbers() {
        let (recipe, _, _) = makeRecipe(["A", "B", "C"])
        recipe.insertStep(Step(title: "X"), at: 1)
        #expect(titles(recipe) == ["A", "X", "B", "C"])
        #expect(indexes(recipe) == [0, 1, 2, 3])
    }

    @Test func insertAtStartAndClampedEnd() {
        let (recipe, _, _) = makeRecipe(["A", "B"])
        recipe.insertStep(Step(title: "first"), at: 0)
        recipe.insertStep(Step(title: "last"), at: 99)
        #expect(titles(recipe) == ["first", "A", "B", "last"])
        #expect(indexes(recipe) == [0, 1, 2, 3])
    }

    @Test func deleteRenumbersAndRemoves() {
        let (recipe, context, container) = makeRecipe(["A", "B", "C", "D"])
        withExtendedLifetime(container) {}
        recipe.deleteSteps(at: IndexSet([1, 2]), in: context)
        #expect(titles(recipe) == ["A", "D"])
        #expect(indexes(recipe) == [0, 1])
    }

    @Test func moveDownAndUp() {
        let (recipe, _, _) = makeRecipe(["A", "B", "C", "D"])
        recipe.moveSteps(from: IndexSet(integer: 0), to: 3) // A after C
        #expect(titles(recipe) == ["B", "C", "A", "D"])
        recipe.moveSteps(from: IndexSet(integer: 3), to: 0) // D to front
        #expect(titles(recipe) == ["D", "B", "C", "A"])
        #expect(indexes(recipe) == [0, 1, 2, 3])
    }

    @Test func deletingRecipeRemovesItsSteps() throws {
        let (recipe, context, container) = makeRecipe(["A", "B"])
        withExtendedLifetime(container) {}
        recipe.addIngredient(Ingredient(name: "salt"))
        try context.save()
        recipe.delete(from: context)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Recipe>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Step>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Ingredient>()).isEmpty)
    }
}
