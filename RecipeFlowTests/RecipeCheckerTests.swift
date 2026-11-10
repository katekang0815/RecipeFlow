//
//  RecipeCheckerTests.swift
//  RecipeFlowTests
//

import Testing
@testable import RecipeFlow

struct RecipeCheckerTests {
    @Test func completeRecipeIsReady() {
        let text = """
        Ingredients
        2 cups flour
        1 cup water
        Directions
        1. Mix the flour and water.
        2. Bake for 20 minutes.
        """
        #expect(RecipeChecker.check(text: text) == .ready)
    }

    @Test func koreanRecipeIsReady() {
        let text = """
        재료
        밥 2공기
        김치 1컵
        만드는 법
        1. 김치를 볶는다.
        2. 밥을 넣고 볶는다.
        """
        #expect(RecipeChecker.check(text: text) == .ready)
    }

    @Test func proseIsRejected() {
        let text = """
        The weather was lovely today and we walked along the river for a long time.
        Afterwards we sat down and talked about everything that had happened this year.
        """
        #expect(RecipeChecker.check(text: text) == .rejected)
    }

    @Test func newsArticleWithNumbersIsRejected() {
        let text = """
        Shares rose 3.5 percent on Tuesday after the company reported its results.
        Analysts had expected a smaller gain, according to the report published in March.
        The chief executive said the outlook for the rest of the year remained strong.
        """
        #expect(RecipeChecker.check(text: text) == .rejected)
    }

    @Test func emptyAndWhitespaceAreRejected() {
        #expect(RecipeChecker.check(text: "") == .rejected)
        #expect(RecipeChecker.check(text: "  \n \n") == .rejected)
    }

    @Test func onlyWebPageJunkIsRejected() {
        #expect(RecipeChecker.check(text: "Advertisement\nPrint\nwww.example.com\n12") == .rejected)
    }

    @Test func ingredientsWithoutStepsIsPartial() {
        let text = "Ingredients\n2 cups flour\n1 cup water\n3 eggs"
        #expect(RecipeChecker.check(text: text) == .partial(.noSteps))
    }

    @Test func stepsWithoutIngredientsIsPartial() {
        let text = "1. Mix the flour and water.\n2. Bake for 20 minutes."
        #expect(RecipeChecker.check(text: text) == .partial(.noIngredients))
    }

    @Test func tooFewItemsIsPartial() {
        let text = "Ingredients\n2 cups flour\nDirections\n1. Bake.\n2. Cool."
        #expect(RecipeChecker.check(text: text) == .partial(.fewItems(ingredients: 1, steps: 2)))
    }

    @Test func partialMessagesSayWhatIsMissing() {
        #expect(RecipeCheck.Issue.noSteps.message.contains("No steps"))
        #expect(RecipeCheck.Issue.noIngredients.message.contains("No ingredients"))
        #expect(RecipeCheck.Issue.fewItems(ingredients: 1, steps: 2).message
                == "Only 1 ingredient and 2 steps were found.")
    }
}
