//
//  RecipeEditingTests.swift
//  RecipeFlowTests
//

import Testing
import Foundation
import SwiftData
@testable import RecipeFlow

@MainActor
struct RecipeEditingTests {
    private let tangzhong = """
    Tangzhong Bread
    Ingredients
    Tangzhong:
    40g bread flour
    200g water

    580g bread flour
    salt to taste
    egg wash (1 egg yolk + milk)
    Directions
    1. Mix 40g flour with 200g water. Stir until thick.
    2. Refrigerate for 6 hours.
    3. Bake for 25 minutes.
    """

    private let bulleted = """
    1. Roast the Garlic
    • Preheat: Set your oven to 375°F (190°C).
    • Prep: Slice just the tips off the 5 garlic bulbs.
    2. Layer 1: Brown the Meat. Keep the heat high.
    • Heat the pan: Drizzle oil into a skillet.
    3. Finish
    """

    private let korean = """
    재료
    밥 2공기
    김치 1컵
    계란 2개
    소금 약간
    양념
    간장 1큰술
    만드는 법
    1. 팬에 기름을 두르고 김치를 볶는다.
    2. 밥을 넣고 함께 볶는다.
    3. 계란 프라이를 올린다.
    """

    private func container() -> ModelContainer {
        PersistenceController.previewContainer(withSample: false)
    }

    // MARK: Recipe to text

    @Test func ingredientsBecomeOneLineEachWithGroupsSeparated() {
        let c = container()
        let recipe = Recipe.create(from: tangzhong, in: c.mainContext)
        #expect(recipe.ingredientsText == """
        Tangzhong:
        40 g bread flour
        200 g water

        580 g bread flour
        salt to taste
        egg wash (1 egg yolk + milk)
        """)
    }

    @Test func stepsBecomeNumberedLinesWithTheirBullets() {
        let c = container()
        // A step's title is its first sentence without the period, so the last line has none.
        let input = "1. Mix flour with water. Stir until thick.\n• Use a whisk.\n2. Refrigerate for 6 hours"
        let recipe = Recipe.create(from: input, in: c.mainContext)
        #expect(recipe.stepsText == input)
    }

    @Test func aRecipeWithoutIngredientsOrStepsGivesEmptyText() {
        let c = container()
        let recipe = Recipe.create(from: "1. Mix.\n2. Bake.", in: c.mainContext)
        #expect(recipe.ingredientsText == "")
        let onlyIngredients = Recipe.create(from: "Ingredients\n2 cups flour", in: c.mainContext)
        #expect(onlyIngredients.stepsText == "")
    }

    // MARK: Text and back again

    @Test func ingredientsSurviveATripThroughText() {
        for source in [tangzhong, korean] {
            let original = RecipeParser.parse(source).ingredients
            let c = container()
            let recipe = Recipe.create(from: source, in: c.mainContext)
            let again = RecipeParser.parse(recipe.ingredientsText, startingWithIngredients: true).ingredients
            #expect(again == original)
            #expect(!original.isEmpty)
        }
    }

    @Test func stepsSurviveATripThroughText() {
        for source in [tangzhong, bulleted, korean] {
            let original = RecipeParser.parse(source).steps
            let c = container()
            let recipe = Recipe.create(from: source, in: c.mainContext)
            let again = RecipeParser.parse(recipe.stepsText).steps
            #expect(again == original)
            #expect(!original.isEmpty)
        }
    }

    // MARK: Saving the edited text

    @Test func addingStepsToAnIngredientsOnlyRecipeKeepsTheIngredients() throws {
        let c = container()
        let recipe = Recipe.create(from: "Ingredients\n2 cups flour\n1 cup water\n3 eggs", in: c.mainContext)
        #expect(recipe.steps.isEmpty)

        let added = RecipeParser.parse("1. Mix the flour and water.\n2. Bake for 20 minutes.")
        recipe.replaceSteps(with: added.steps, in: c.mainContext)

        #expect(recipe.sortedSteps.map(\.title) == ["Mix the flour and water", "Bake for 20 minutes"])
        #expect(recipe.sortedSteps.map(\.sortIndex) == [0, 1])
        #expect(recipe.sortedIngredients.map(\.name) == ["flour", "water", "eggs"])
    }

    @Test func addingIngredientsToAStepsOnlyRecipeKeepsTheSteps() throws {
        let c = container()
        let recipe = Recipe.create(from: "1. Mix.\n2. Bake.", in: c.mainContext)

        let added = RecipeParser.parse("salt\n2 cups flour", startingWithIngredients: true)
        recipe.replaceIngredients(with: added.ingredients, in: c.mainContext)

        #expect(recipe.sortedIngredients.map(\.name) == ["salt", "flour"])
        #expect(recipe.sortedIngredients.map(\.sortIndex) == [0, 1])
        #expect(recipe.steps.count == 2)
    }

    @Test func editingReplacesTheOldItemsAndLeavesNoneBehind() throws {
        let c = container()
        let context = c.mainContext
        let recipe = Recipe.create(from: tangzhong, in: context)

        let edited = RecipeParser.parse(recipe.stepsText + "\n4. Cool on a rack.")
        recipe.replaceSteps(with: edited.steps, in: context)
        let editedIngredients = RecipeParser.parse("2 cups flour", startingWithIngredients: true)
        recipe.replaceIngredients(with: editedIngredients.ingredients, in: context)
        try context.save()

        #expect(recipe.sortedSteps.count == 4)
        #expect(recipe.sortedSteps.last?.title == "Cool on a rack")
        #expect(recipe.ingredients.count == 1)
        // The replaced records are really gone from the store.
        #expect(try context.fetch(FetchDescriptor<Step>()).count == 4)
        #expect(try context.fetch(FetchDescriptor<Ingredient>()).count == 1)
    }

    @Test func editingOneRecipeDoesNotTouchAnother() throws {
        let c = container()
        let first = Recipe.create(from: tangzhong, in: c.mainContext)
        let second = Recipe.create(from: tangzhong, in: c.mainContext)
        first.replaceSteps(with: RecipeParser.parse("1. Only step.").steps, in: c.mainContext)

        #expect(first.steps.count == 1)
        #expect(second.steps.count == 3)
        #expect(second.ingredients.count == 5)
    }

    // MARK: Parsing an ingredient list that has no header

    @Test func aHeaderlessIngredientListKeepsEveryLine() {
        let recipe = RecipeParser.parse("salt\n2 cups flour\nTangzhong:\n40g water", startingWithIngredients: true)
        #expect(recipe.title == nil)
        #expect(recipe.ingredients.map(\.name) == ["salt", "flour", "water"])
        #expect(recipe.ingredients.map(\.group) == [nil, nil, "Tangzhong"])
    }

    @Test func aHeaderlessIngredientListStillAcceptsAHeaderAndSeparatesSteps() {
        let recipe = RecipeParser.parse("Ingredients\n2 cups flour\n1. Mix.", startingWithIngredients: true)
        #expect(recipe.ingredients.map(\.name) == ["flour"])
        #expect(recipe.steps.map(\.title) == ["Mix"])
    }

    @Test func numberedIngredientsStayIngredientsWhenTheTextIsAList() {
        let recipe = RecipeParser.parse("1. 2 cups flour\n2. 1 cup sugar", startingWithIngredients: true)
        #expect(recipe.ingredients.map(\.name) == ["flour", "sugar"])
        #expect(recipe.steps.isEmpty)
    }

    @Test func withoutTheFlagAShortFirstLineIsATitle() {
        #expect(RecipeParser.parse("salt\n2 cups flour").title == "salt")
    }
}
