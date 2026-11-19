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
    private let ingredients = "40g bread flour\n200g water\n\n580g bread flour"
    private let steps = "1. Mix 40g flour with 200g water. Stir until thick.\n2. Refrigerate for 6 hours.\n3. Bake for 25 minutes."

    // MARK: Saving

    @Test func savesIngredientsInOrderAsWritten() {
        let context = PersistenceController.previewContainer(withSample: false).mainContext
        let recipe = makeRecipe(ingredients: ingredients, in: context)

        let items = recipe.sortedIngredients
        #expect(items.map(\.name) == ["40g bread flour", "200g water", "", "580g bread flour"], "the empty line is kept")
        #expect(items.map(\.sortIndex) == [0, 1, 2, 3])
    }

    @Test func savesEachStepAsOneParagraphInOrder() {
        let context = PersistenceController.previewContainer(withSample: false).mainContext
        let recipe = makeRecipe(steps: steps, in: context)

        let saved = recipe.sortedSteps
        #expect(saved.map(\.title) == ["Mix 40g flour with 200g water. Stir until thick.", "Refrigerate for 6 hours.", "Bake for 25 minutes."])
        #expect(saved.map(\.sortIndex) == [0, 1, 2])
        #expect(saved.allSatisfy { $0.detail.isEmpty })
    }

    @Test func aNewRecipeHasNoNoteAndNoLink() {
        let context = PersistenceController.previewContainer(withSample: false).mainContext
        let recipe = makeRecipe(ingredients: ingredients, steps: steps, in: context)
        #expect(recipe.note == "")
        #expect(recipe.sourceURL == nil)
        #expect(recipe.thumbnail == nil)
    }

    @Test func aRecipeWithoutATitleIsUntitled() {
        let context = PersistenceController.previewContainer(withSample: false).mainContext
        let recipe = makeRecipe(ingredients: "2 cups flour", steps: "1. Mix.", in: context)
        // The stored title stays empty so it can be typed into; lists show "Untitled recipe".
        #expect(recipe.title == "")
        #expect(recipe.displayTitle == "Untitled recipe")
    }

    @Test func emptyTitleFromAnOlderRecipeShowsAsUntitled() {
        #expect(Recipe(title: "").displayTitle == "Untitled recipe")
        #expect(Recipe(title: "   ").displayTitle == "Untitled recipe", "a blank title counts as empty")
        #expect(Recipe(title: "Toast").displayTitle == "Toast")
    }

    @Test func deletingARecipeRemovesItsIngredientsAndSteps() throws {
        let context = PersistenceController.previewContainer(withSample: false).mainContext
        let recipe = makeRecipe(ingredients: ingredients, steps: steps, in: context)
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
            let recipe = makeRecipe(title: "Tangzhong Bread", ingredients: ingredients, steps: steps, in: container.mainContext)
            recipe.note = "Rest overnight."
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
        #expect(recipe.sortedIngredients.count == 4)
        #expect(recipe.sortedSteps.count == 3)
        #expect(recipe.note == "Rest overnight.")
        #expect(recipe.sourceURL == "https://www.youtube.com/watch?v=nqsoMyxHTbc")
    }
}
