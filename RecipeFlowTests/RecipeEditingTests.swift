//
//  RecipeEditingTests.swift
//  RecipeFlowTests
//

import Testing
import Foundation
import SwiftData
@testable import RecipeFlow

/// A saved recipe built the way the screen builds it: each section on its own.
@MainActor
func makeRecipe(
    title: String = "",
    ingredients: String = "",
    steps: String = "",
    in context: ModelContext
) -> Recipe {
    let recipe = Recipe(title: title)
    // Insert first: SwiftData crashes if an un-inserted model touches a to-many relationship.
    context.insert(recipe)
    recipe.replaceIngredients(withLines: SectionText.lines(ingredients), in: context)
    recipe.replaceSteps(with: StepParser.parse(steps), in: context)
    return recipe
}

@MainActor
struct RecipeEditingTests {
    private func container() -> ModelContainer {
        PersistenceController.previewContainer(withSample: false)
    }

    // MARK: Recipe to text

    @Test func ingredientsBecomeOneLineEach() {
        let c = container()
        let recipe = makeRecipe(ingredients: "40g bread flour\n  200g water \n\nsalt to taste", in: c.mainContext)
        #expect(recipe.ingredientsText == "40g bread flour\n200g water\nsalt to taste")
    }

    @Test func olderIngredientsStillReadAsOneLine() {
        let c = container()
        let recipe = Recipe(title: "Old")
        c.mainContext.insert(recipe)
        recipe.addIngredient(Ingredient(name: "bread flour", quantity: "40", unit: "g"))
        recipe.addIngredient(Ingredient(name: "salt", quantity: "to taste"))
        recipe.addIngredient(Ingredient(name: "egg wash", prepNote: "1 egg yolk + milk"))
        #expect(recipe.ingredientsText == "40 g bread flour\nsalt to taste\negg wash (1 egg yolk + milk)")
    }

    @Test func stepsBecomeNumberedLines() {
        let c = container()
        let recipe = makeRecipe(steps: "1. Mix flour with water. Stir until thick.\n2. Refrigerate for 6 hours", in: c.mainContext)
        #expect(recipe.stepsText == "1. Mix flour with water. Stir until thick.\n2. Refrigerate for 6 hours")
    }

    @Test func aRecipeWithoutIngredientsOrStepsGivesEmptyText() {
        let c = container()
        #expect(makeRecipe(steps: "1. Mix.\n2. Bake.", in: c.mainContext).ingredientsText == "")
        #expect(makeRecipe(ingredients: "2 cups flour", in: c.mainContext).stepsText == "")
    }

    // MARK: Text and back again

    @Test func stepsSurviveATripThroughText() {
        let sources = [
            "1. Mix flour with water. Stir until thick.\n2. Refrigerate for 6 hours.\n3. Bake for 25 minutes.",
            "1. Roast the Garlic\n• Preheat: Set your oven.\n• Prep: Slice the tips.\n2. Brown the Meat. Keep the heat high.",
            "1. 팬에 기름을 두르고 김치를 볶는다.\n2. 밥을 넣고 함께 볶는다.",
        ]
        for source in sources {
            let original = StepParser.parse(source)
            let recipe = makeRecipe(steps: source, in: container().mainContext)
            #expect(StepParser.parse(recipe.stepsText) == original)
            #expect(!original.isEmpty)
        }
    }

    @Test func ingredientsSurviveATripThroughText() {
        let source = "Tangzhong:\n40g bread flour\n200g water\n\n580g bread flour\n소금 약간"
        let recipe = makeRecipe(ingredients: source, in: container().mainContext)
        #expect(recipe.ingredientsText.components(separatedBy: "\n") == SectionText.lines(source))
    }

    // MARK: Saving the edited text

    @Test func addingStepsToAnIngredientsOnlyRecipeKeepsTheIngredients() {
        let c = container()
        let recipe = makeRecipe(ingredients: "2 cups flour\n1 cup water\n3 eggs", in: c.mainContext)
        recipe.replaceSteps(with: StepParser.parse("1. Mix the flour and water.\n2. Bake for 20 minutes."), in: c.mainContext)

        #expect(recipe.sortedSteps.map(\.title) == ["Mix the flour and water", "Bake for 20 minutes"])
        #expect(recipe.sortedSteps.map(\.sortIndex) == [0, 1])
        #expect(recipe.sortedIngredients.map(\.name) == ["2 cups flour", "1 cup water", "3 eggs"])
    }

    @Test func addingIngredientsToAStepsOnlyRecipeKeepsTheSteps() {
        let c = container()
        let recipe = makeRecipe(steps: "1. Mix.\n2. Bake.", in: c.mainContext)
        recipe.replaceIngredients(withLines: ["salt", "2 cups flour"], in: c.mainContext)

        #expect(recipe.sortedIngredients.map(\.name) == ["salt", "2 cups flour"])
        #expect(recipe.sortedIngredients.map(\.sortIndex) == [0, 1])
        #expect(recipe.steps.count == 2)
    }

    @Test func editingReplacesTheOldItemsAndLeavesNoneBehind() throws {
        let context = container().mainContext
        let recipe = makeRecipe(ingredients: "a\nb\nc", steps: "1. One.\n2. Two.\n3. Three.", in: context)

        recipe.replaceSteps(with: StepParser.parse(recipe.stepsText + "\n4. Cool on a rack."), in: context)
        recipe.replaceIngredients(withLines: ["2 cups flour"], in: context)
        try context.save()

        #expect(recipe.sortedSteps.count == 4)
        #expect(recipe.sortedSteps.last?.title == "Cool on a rack")
        #expect(recipe.ingredients.count == 1)
        // The replaced records are really gone from the store.
        #expect(try context.fetch(FetchDescriptor<Step>()).count == 4)
        #expect(try context.fetch(FetchDescriptor<Ingredient>()).count == 1)
    }

    @Test func editingOneRecipeDoesNotTouchAnother() {
        let context = container().mainContext
        let first = makeRecipe(ingredients: "a\nb", steps: "1. One.\n2. Two.\n3. Three.", in: context)
        let second = makeRecipe(ingredients: "a\nb", steps: "1. One.\n2. Two.\n3. Three.", in: context)
        first.replaceSteps(with: StepParser.parse("1. Only step."), in: context)

        #expect(first.steps.count == 1)
        #expect(second.steps.count == 3)
        #expect(second.ingredients.count == 2)
    }
}
