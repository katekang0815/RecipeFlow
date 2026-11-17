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
        #expect(SectionText.noStepsMessage.hasPrefix("Only numbered steps are valid"))
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
        #expect(StepParser.parse(text).map(\.title) == ["Mix.", "Bake.", "Cool.", "Slice."])
    }

    // MARK: Numbering on from the steps already there

    @Test func newStepsContinueTheNumbersWhateverTheyStartAt() {
        #expect(SectionText.appendingSteps("1. Cool.\n2. Slice.", to: "1. Mix.\n2. Bake.\n3. Rest.")
                == "1. Mix.\n2. Bake.\n3. Rest.\n4. Cool.\n5. Slice.")
        #expect(SectionText.appendingSteps("7. Cool.\n9. Slice.", to: "1. Mix.\n2. Bake.")
                == "1. Mix.\n2. Bake.\n3. Cool.\n4. Slice.")
    }

    @Test func theSameStepsAddedAgainAreKeptWithNewNumbers() {
        let steps = "1. Mix.\n2. Bake.\n3. Cool."
        let text = SectionText.appendingSteps(steps, to: steps)
        #expect(text == "1. Mix.\n2. Bake.\n3. Cool.\n4. Mix.\n5. Bake.\n6. Cool.")
        #expect(StepParser.parse(text).count == 6)
    }

    @Test func eachNewStepIsOneLineWhateverNumberStyleItHad() {
        let text = SectionText.appendingSteps("② Heat the cream. Gently.\n(My mixer: level 9)\n③ Seal.", to: "1. Mix.")
        #expect(text == "1. Mix.\n2. Heat the cream. Gently. (My mixer: level 9)\n3. Seal.")
    }

    @Test func stepsWhoseCirclesWereReadAsSymbolsAreNumberedToo() {
        #expect(SectionText.appendingSteps("® Lower.\n® Raise.", to: "1. Mix.\n2. Bake.") == "1. Mix.\n2. Bake.\n3. Lower.\n4. Raise.")
    }

    @Test func stepsAddedToAnEmptyCardStartAtOne() {
        #expect(SectionText.appendingSteps("4. Mix.\n5. Bake.", to: "") == "1. Mix.\n2. Bake.")
    }

    @Test func textWithNoNumberIsLeftAsItIs() {
        // The screen does not add it: only numbered steps are valid.
        #expect(SectionText.appendingSteps("Mix it.\nBake it.", to: "1. Mix.") == "1. Mix.\nMix it.\nBake it.")
        #expect(StepParser.parse("Mix it.\nBake it.").isEmpty)
    }

    @Test func textWithAnyNumberKeepsItsOtherLinesInTheStep() {
        // One line has a number, so the numbers are used and the lines under it stay with it.
        #expect(SectionText.appendingSteps("1. Grind.\nFor the cream.\nSeal.", to: "")
                == "1. Grind. For the cream. Seal.")
    }
}
