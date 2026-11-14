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
