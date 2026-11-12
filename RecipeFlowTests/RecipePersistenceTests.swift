//
//  RecipePersistenceTests.swift
//  RecipeFlowTests
//

import Testing
import Foundation
import SwiftData
@testable import RecipeFlow

@MainActor
struct RecipePersistenceTests {
    private let text = """
    Tangzhong Bread
    Advertisement
    Ingredients
    Tangzhong:
    40g bread flour
    200g water

    580g bread flour
    egg wash (1 egg yolk + milk)
    Directions
    1. Mix 40g flour with 200g water. Stir until thick.
    2. Refrigerate for 6 hours.
    3. Bake for 25 minutes.
    """

    private let modelTypes: [any PersistentModel.Type] = [Recipe.self, Ingredient.self, Step.self]

    // MARK: Saving

    @Test func savesIngredientsInOrderWithGroupsAndNotes() throws {
        let container = PersistenceController.previewContainer(withSample: false)
        let recipe = Recipe.create(from: text, in: container.mainContext)

        let items = recipe.sortedIngredients
        #expect(items.map(\.name) == ["bread flour", "water", "bread flour", "egg wash"])
        #expect(items.map(\.sortIndex) == [0, 1, 2, 3])
        #expect(items.map(\.group) == ["Tangzhong", "Tangzhong", nil, nil])
        #expect(items[0].quantity == "40")
        #expect(items[0].unit == "g")
        #expect(items[3].prepNote == "1 egg yolk + milk")
    }

    @Test func savesStepsInOrderWithTitleAndDetail() throws {
        let container = PersistenceController.previewContainer(withSample: false)
        let recipe = Recipe.create(from: text, in: container.mainContext)

        let steps = recipe.sortedSteps
        #expect(steps.map(\.title) == ["Mix 40g flour with 200g water", "Refrigerate for 6 hours", "Bake for 25 minutes"])
        #expect(steps.map(\.sortIndex) == [0, 1, 2])
        #expect(steps[0].detail == "Stir until thick.")
    }

    @Test func savesTitleRawTextAndIgnoredLines() throws {
        let container = PersistenceController.previewContainer(withSample: false)
        let recipe = Recipe.create(from: text, in: container.mainContext)

        #expect(recipe.title == "Tangzhong Bread")
        #expect(recipe.rawText == text)
        #expect(recipe.ignoredLines == ["Advertisement"])
    }

    @Test func recipeWithoutATitleIsUntitled() throws {
        let container = PersistenceController.previewContainer(withSample: false)
        let recipe = Recipe.create(from: "Ingredients\n2 cups flour\nDirections\n1. Mix.", in: container.mainContext)
        #expect(recipe.title == "Untitled recipe")
    }

    @Test func emptyTitleFromAnOlderRecipeShowsAsUntitled() {
        #expect(Recipe(title: "").displayTitle == "Untitled recipe")
        #expect(Recipe(title: "Toast").displayTitle == "Toast")
    }

    @Test func eachCreateMakesAnotherRecipe() throws {
        let container = PersistenceController.previewContainer(withSample: false)
        Recipe.create(from: text, in: container.mainContext)
        Recipe.create(from: text, in: container.mainContext)

        let saved = try container.mainContext.fetch(FetchDescriptor<Recipe>())
        #expect(saved.count == 2)
        #expect(saved.allSatisfy { $0.ingredients.count == 4 && $0.steps.count == 3 })
    }

    @Test func deletingARecipeRemovesItsIngredientsAndSteps() throws {
        let container = PersistenceController.previewContainer(withSample: false)
        let context = container.mainContext
        let recipe = Recipe.create(from: text, in: context)
        recipe.delete(from: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Recipe>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Ingredient>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Step>()).isEmpty)
    }

    // MARK: Surviving a restart

    @Test func recipeIsStillThereAfterReopeningTheStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecipeFlowTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("recipes.store")

        // First "launch": save a recipe, then let the container go.
        do {
            let container = try ModelContainer(
                for: Recipe.self, Ingredient.self, Step.self,
                configurations: ModelConfiguration(url: storeURL)
            )
            let recipe = Recipe.create(from: text, in: container.mainContext)
            recipe.sourceURL = "https://www.youtube.com/watch?v=nqsoMyxHTbc"
            try container.mainContext.save()
        }

        // Second "launch": a fresh container on the same file.
        let reopened = try ModelContainer(
            for: Recipe.self, Ingredient.self, Step.self,
            configurations: ModelConfiguration(url: storeURL)
        )
        let saved = try reopened.mainContext.fetch(FetchDescriptor<Recipe>())
        let recipe = try #require(saved.first)
        #expect(saved.count == 1)
        #expect(recipe.title == "Tangzhong Bread")
        #expect(recipe.sortedIngredients.map(\.group) == ["Tangzhong", "Tangzhong", nil, nil])
        #expect(recipe.sortedSteps.count == 3)
        #expect(recipe.ignoredLines == ["Advertisement"])
        #expect(recipe.sourceURL == "https://www.youtube.com/watch?v=nqsoMyxHTbc")
    }

    @Test func newRecipeHasNoSourceLink() {
        let container = PersistenceController.previewContainer(withSample: false)
        #expect(Recipe.create(from: text, in: container.mainContext).sourceURL == nil)
    }
}
