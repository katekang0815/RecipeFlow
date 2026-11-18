//
//  StepEditingTests.swift
//  RecipeFlowTests
//

import Testing
@testable import RecipeFlow

/// Return inside the steps text starts the next step where the cursor is.
struct StepEditingTests {
    /// Presses Return with the cursor after `before`, in a text whose rest is `after`.
    private func pressReturn(_ before: String, _ after: String) -> StepEditing.Result? {
        StepEditing.splitAtReturn(old: before + after, new: before + "\n" + after)
    }

    @Test func returnInTheMiddleOfAStepSplitsItAndRenumbersTheRest() {
        let before = "1. Grind the tea.\n2. Boil the milk. Cover with wrap.\n3. Place egg whites. In a medium bowl, add milk and mix until emulsified."
        let result = pressReturn(before + " ", "8 Sift in the cake flour.\n4. Pour into a pan.")
        #expect(result?.text == "1. Grind the tea.\n2. Boil the milk. Cover with wrap.\n3. Place egg whites. In a medium bowl, add milk and mix until emulsified.\n4. 8 Sift in the cake flour.\n5. Pour into a pan.")
    }

    @Test func theCursorGoesInFrontOfTheNewSteps() throws {
        let result = try #require(pressReturn("1. Mix well. ", "Bake it.\n2. Cool."))
        #expect(result.text == "1. Mix well.\n2. Bake it.\n3. Cool.")
        let index = result.text.index(result.text.startIndex, offsetBy: result.caret)
        #expect(result.text[index...].hasPrefix("Bake it."))
    }

    @Test func returnAtTheEndOfAStepMakesAnEmptyNextStep() throws {
        let result = try #require(pressReturn("1. Mix.\n2. Bake.", ""))
        #expect(result.text == "1. Mix.\n2. Bake.\n3. ")
        #expect(result.caret == result.text.count)
    }

    @Test func returnAtTheEndOfAnEarlierStepMakesAnEmptyStepInBetween() throws {
        let result = try #require(pressReturn("1. Mix.", "\n2. Bake.\n3. Cool."))
        #expect(result.text == "1. Mix.\n2. \n3. Bake.\n4. Cool.")
        #expect(result.caret == "1. Mix.\n2. ".count)
    }

    @Test func returnInALineOfAStepThatRunsOverSeveralLines() throws {
        let result = try #require(pressReturn("1. Mix the flour with the water and stir until", " thick.\ncontinued here.\n2. Bake."))
        #expect(result.text == "1. Mix the flour with the water and stir until\n2. thick.\ncontinued here.\n3. Bake.")
    }

    @Test func aCursorInFrontOfAStepsNumberCountsAsJustAfterIt() throws {
        let result = try #require(StepEditing.splitAtReturn(old: "1. Mix.\n2. Bake.", new: "1. Mix.\n\n2. Bake."))
        // Return at the very start of line 2 (the break lands before its number).
        #expect(result.text.hasPrefix("1. Mix."))
        #expect(StepParser.parse(result.text).count >= 2)
    }

    @Test func numbersAreWrittenAsPlainNumbersWhateverStyleTheyHad() throws {
        let result = try #require(pressReturn("① Grind the tea.", " Heat.\n② Cool."))
        #expect(result.text == "1. Grind the tea.\n2. Heat.\n3. Cool.")
    }

    @Test func aNumberAloneOnItsLineKeepsItsText() throws {
        let result = try #require(pressReturn("1\nMix the flour.", " Stir.\n2\nBake."))
        #expect(result.text == "1. \nMix the flour.\n2. Stir.\n3. \nBake.")
    }

    @Test func returnIsAPlainLineBreakWhenThereIsNoStepYet() {
        #expect(pressReturn("Mix it", " now") == nil)
        #expect(pressReturn("", "") == nil)
    }

    @Test func returnAboveTheFirstStepIsAPlainLineBreak() {
        #expect(pressReturn("Directions", "\n1. Mix.\n2. Bake.") == nil)
    }

    @Test func aChangeThatIsNotOneLineBreakIsLeftAlone() {
        #expect(StepEditing.splitAtReturn(old: "1. Mix.", new: "1. Mix.a") == nil)
        #expect(StepEditing.splitAtReturn(old: "1. Mix.", new: "1. Mix.\n\n") == nil)
        #expect(StepEditing.splitAtReturn(old: "1. Mix.", new: "1. Mix.") == nil)
    }

    @Test func theCaretTellsApartIdenticalResultsOfBlankLines() throws {
        // Old and new are the same text wherever the break went in a run of line breaks; the caret picks one.
        let old = "1. Mix.\n\n2. Bake."
        let new = "1. Mix.\n\n\n2. Bake."
        let atEndOfFirstLine = try #require(StepEditing.splitAtReturn(old: old, new: new, caret: 8))
        let inTheBlankLine = try #require(StepEditing.splitAtReturn(old: old, new: new, caret: 9))
        #expect(atEndOfFirstLine.text.hasPrefix("1. Mix.\n2. "))
        #expect(inTheBlankLine.text.hasPrefix("1. Mix.\n"))
    }
}
