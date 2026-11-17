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

    @Test func newStepsKeepTheirOtherLinesAndAnyNumberStyle() {
        let text = SectionText.appendingSteps("② Heat the cream. Gently.\n(My mixer: level 9)\n③ Seal.", to: "1. Mix.")
        #expect(text == "1. Mix.\n2. Heat the cream. Gently.\n(My mixer: level 9)\n3. Seal.")
    }

    @Test func stepsWhoseCirclesWereReadAsSymbolsAreNumberedToo() {
        #expect(SectionText.appendingSteps("® Lower.\n® Raise.", to: "1. Mix.\n2. Bake.") == "1. Mix.\n2. Bake.\n3. Lower.\n4. Raise.")
    }

    @Test func stepsAddedToAnEmptyCardStartAtOne() {
        #expect(SectionText.appendingSteps("4. Mix.\n5. Bake.", to: "") == "1. Mix.\n2. Bake.")
    }

    @Test func textWithNoNumberAnywhereBecomesOneStepPerSentence() {
        // A photo whose numbers were lost: a bullet, nothing, nothing, a star.
        let photo = "• Grind the tea leaves with a coffee grinder.\nFor the cream, add ground tea.\nSeal and refrigerate for at least 3 hours.\n* Boil the milk with the tea in the same way."
        #expect(SectionText.appendingSteps(photo, to: "1. Mix.\n2. Bake.\n3. Cool.\n4. Rest.\n5. Serve.")
                == "1. Mix.\n2. Bake.\n3. Cool.\n4. Rest.\n5. Serve.\n6. Grind the tea leaves with a coffee grinder.\n7. For the cream, add ground tea.\n8. Seal and refrigerate for at least 3 hours.\n9. Boil the milk with the tea in the same way.")
    }

    @Test func aSentenceThatWrapsOntoTheNextLineIsOneStep() {
        #expect(SectionText.appendingSteps("Cover with plastic wrap and let\nsit for 20 minutes.\nBake.", to: "1. Mix.")
                == "1. Mix.\n2. Cover with plastic wrap and let sit for 20 minutes.\n3. Bake.")
    }

    @Test func aLineInBracketsStaysWithTheStepAbove() {
        let text = SectionText.appendingSteps("The meringue becomes glossy.\n(My mixer: level 9 - 2 min.)\nWhen lifted, it stands.", to: "")
        #expect(text == "1. The meringue becomes glossy.\n(My mixer: level 9 - 2 min.)\n2. When lifted, it stands.")
        #expect(StepParser.parse(text).count == 2)
    }

    @Test func oneLineWithNoNumberIsOneStep() {
        #expect(SectionText.appendingSteps("Mix it", to: "1. Mix.") == "1. Mix.\n2. Mix it")
    }

    @Test func textWithAnyNumberIsNotSplitBySentence() {
        // One line has a number, so the numbers are used and the lines under it stay with it.
        #expect(SectionText.appendingSteps("1. Grind.\nFor the cream.\nSeal.", to: "")
                == "1. Grind.\nFor the cream.\nSeal.")
    }
}
