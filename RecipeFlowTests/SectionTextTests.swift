//
//  SectionTextTests.swift
//  RecipeFlowTests
//

import Testing
@testable import RecipeFlow

struct SectionTextTests {
    private func status(_ section: RecipeSection, _ text: String) -> String? {
        SectionText.status(section, text: text, parsed: SectionText.parse(section, text))
    }

    // MARK: Parsing a card's text

    @Test func stepsAreTheNumberedLines() {
        let parsed = SectionText.parse(.steps, "1. Mix.\n2. Bake.")
        #expect(SectionText.count(.steps, parsed) == 2)
        #expect(SectionText.count(.ingredients, parsed) == 0)
    }

    @Test func ingredientsNeedNoHeading() {
        let parsed = SectionText.parse(.ingredients, "salt\n2 cups flour")
        #expect(parsed.ingredients.map(\.name) == ["salt", "flour"])
        #expect(parsed.title == nil)
    }

    @Test func notesAreKeptAsWrittenOneLineEach() {
        let parsed = SectionText.parse(.notes, "  Rest overnight.  \n\n1. Not a step here\n   \nServe warm.")
        #expect(parsed.note == ["Rest overnight.", "1. Not a step here", "Serve warm."])
        #expect(SectionText.count(.notes, parsed) == 3)
        #expect(parsed.steps.isEmpty && parsed.ingredients.isEmpty)
    }

    @Test func blankTextHoldsNothingInAnySection() {
        for section in [RecipeSection.ingredients, .steps, .notes] {
            #expect(SectionText.count(section, SectionText.parse(section, "  \n \n")) == 0)
        }
    }

    // MARK: Adding a photo's text to a card

    @Test func aPhotosTextGoesAfterWhatIsAlreadyThere() {
        #expect(SectionText.appending("3. Cool.", to: "1. Mix.\n2. Bake.") == "1. Mix.\n2. Bake.\n3. Cool.")
    }

    @Test func anEmptyCardTakesThePhotosTextAsIs() {
        #expect(SectionText.appending("1. Mix.", to: "") == "1. Mix.")
        #expect(SectionText.appending("1. Mix.", to: "  \n ") == "1. Mix.")
    }

    @Test func trailingBlankLinesAreNotKeptBeforeTheAddition() {
        #expect(SectionText.appending("salt", to: "2 cups flour\n\n") == "2 cups flour\nsalt")
    }

    @Test func morePhotosOfNumberedStepsAreAllCountedAsSteps() {
        // A second page that starts again at 1 adds its steps after the first page's.
        let text = SectionText.appending("1. Cool.\n2. Slice.", to: "1. Mix.\n2. Bake.")
        let parsed = SectionText.parse(.steps, text)
        #expect(parsed.steps.map(\.title) == ["Mix", "Bake", "Cool", "Slice"])
    }

    @Test func morePhotosOfIngredientsAreAllCountedAsIngredients() {
        let text = SectionText.appending("1 tsp salt\nbutter", to: "2 cups flour")
        let parsed = SectionText.parse(.ingredients, text)
        #expect(parsed.ingredients.map(\.name) == ["flour", "salt", "butter"])
    }

    // MARK: The line under the field

    @Test func statusSaysWhatWasFound() {
        #expect(status(.steps, "1. Mix.\n2. Bake.") == "2 steps found.")
        #expect(status(.steps, "1. Mix.") == "1 step found.")
        #expect(status(.ingredients, "2 cups flour\nsalt") == "2 ingredients found.")
        #expect(status(.ingredients, "salt") == "1 ingredient found.")
    }

    @Test func statusExplainsWhyNothingWouldBeSaved() {
        #expect(status(.steps, "Mix it") == "No numbered steps found. Start each step with a number, like 1. 2. 3.")
        #expect(status(.ingredients, "1. Mix.\n2. Bake.") == "No ingredients found. Put each ingredient on its own line.")
    }

    @Test func statusSaysWhatTheCardLeavesOut() {
        #expect(status(.steps, "1. Mix.\nIngredients\n2 cups flour\n1 cup water")
                == "1 step found. 2 ingredients in this text will not be added.")
        #expect(status(.ingredients, "2 cups flour\n1. Mix.\n2. Bake.")
                == "1 ingredient found. 2 steps in this text will not be added.")
    }

    @Test func noStatusForBlankTextOrForNotes() {
        #expect(status(.steps, "") == nil)
        #expect(status(.ingredients, "   \n") == nil)
        #expect(status(.notes, "Rest overnight.") == nil)
    }
}
