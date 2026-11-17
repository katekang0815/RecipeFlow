//
//  SectionTextTests.swift
//  RecipeFlowTests
//

import Testing
@testable import RecipeFlow

struct SectionTextTests {
    // MARK: Ingredients and notes are kept as written

    @Test func linesAreTrimmedAndTheEmptyOnesLeftOut() {
        #expect(SectionText.lines("  Rest overnight.  \n\n1. Not a step here\n   \nServe warm.")
                == ["Rest overnight.", "1. Not a step here", "Serve warm."])
        #expect(SectionText.lines("  \n \n") == [])
    }

    @Test func ingredientLinesAreNotInterpreted() {
        #expect(SectionText.lines("Tangzhong:\n40g bread flour\n소금 약간") == ["Tangzhong:", "40g bread flour", "소금 약간"])
    }

    // MARK: Steps

    @Test func stepsStatusCountsTheStepsOrSaysThereAreNone() {
        #expect(SectionText.stepsStatus("1. Mix.\n2. Bake.") == "2 steps found.")
        #expect(SectionText.stepsStatus("1. Mix.") == "1 step found.")
        #expect(SectionText.stepsStatus("Mix it") == SectionText.noStepsMessage)
        #expect(SectionText.stepsStatus("  \n") == nil)
    }

    // MARK: Adding a photo's text to a card

    @Test func aPhotoIsAddedAfterWhatIsThere() {
        #expect(SectionText.appending("3. Cool.", to: "1. Mix.\n2. Bake.") == "1. Mix.\n2. Bake.\n3. Cool.")
        #expect(SectionText.appending("salt", to: "2 cups flour\n\n") == "2 cups flour\nsalt")
    }

    @Test func aPhotoInAnEmptyCardIsJustItsText() {
        #expect(SectionText.appending("1. Mix.", to: "") == "1. Mix.")
        #expect(SectionText.appending("1. Mix.", to: "  \n ") == "1. Mix.")
    }

    @Test func morePhotosOfStepsAreAllReadAtTheirNumbers() {
        let text = SectionText.appending("1. Cool.\n2. Slice.", to: "1. Mix.\n2. Bake.")
        #expect(StepParser.parse(text).map(\.title) == ["Mix", "Bake", "Cool", "Slice"])
    }
}
