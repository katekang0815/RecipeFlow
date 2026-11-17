//
//  StepParserTests.swift
//  RecipeFlowTests
//

import Testing
@testable import RecipeFlow

/// A step starts at a number, in whatever style the number is written.
struct StepParserTests {
    private func titles(_ text: String) -> [String] {
        StepParser.parse(text).map(\.title)
    }

    @Test func plainNumbers() {
        #expect(titles("1. Mix.\n2. Bake.") == ["Mix", "Bake"])
        #expect(titles("1) Mix.\n2) Bake.") == ["Mix", "Bake"])
        #expect(titles("1: Mix.\n2: Bake.") == ["Mix", "Bake"])
        #expect(titles("1、Mix.\n2、Bake.") == ["Mix", "Bake"])
        #expect(titles("1 Mix.\n2 Bake.") == ["Mix", "Bake"])
    }

    @Test func parenthesizedNumbers() {
        #expect(titles("(1) Mix.\n(2) Bake.") == ["Mix", "Bake"])
        #expect(titles("⑴ Mix.\n⑵ Bake.") == ["Mix", "Bake"])
    }

    @Test func circledNumbers() {
        #expect(titles("① Grind.\n② Heat.\n⑳ Done.") == ["Grind", "Heat", "Done"])
        #expect(titles("⒈ Mix.\n⒉ Bake.") == ["Mix", "Bake"])
        #expect(titles("❶ Mix.\n❷ Bake.") == ["Mix", "Bake"])
        #expect(titles("➊ Mix.\n➋ Bake.") == ["Mix", "Bake"])
        #expect(titles("⓫ Mix.\n⓬ Bake.") == ["Mix", "Bake"])
        #expect(titles("㉑ Mix.\n㉘ Bake.") == ["Mix", "Bake"])
        #expect(titles("㊱ Mix.\n㊲ Bake.") == ["Mix", "Bake"])
    }

    @Test func fullWidthDigits() {
        #expect(titles("１．Mix.\n２．Bake.") == ["Mix", "Bake"])
    }

    @Test func romanNumerals() {
        #expect(titles("I. Mix.\nII. Bake.\nIII. Cool.") == ["Mix", "Bake", "Cool"])
        #expect(titles("I) Mix.\nII) Bake.") == ["Mix", "Bake"])
        #expect(titles("(I) Mix.\n(II) Bake.") == ["Mix", "Bake"])
    }

    @Test func letters() {
        #expect(titles("a. Mix.\nb. Bake.\nc. Cool.") == ["Mix", "Bake", "Cool"])
        #expect(titles("a) Mix.\nb) Bake.") == ["Mix", "Bake"])
        #expect(titles("(a) Mix.\n(b) Bake.") == ["Mix", "Bake"])
        #expect(titles("A. Mix.\nB. Bake.") == ["Mix", "Bake"])
    }

    @Test func aWordIsNotALetterNumber() {
        // "e.g." and an ordinary first word are not numbers.
        let steps = StepParser.parse("1. Mix with a whisk, e.g.\nthe big one.\n2. A pinch of salt.")
        #expect(steps.count == 2)
        #expect(steps[1].title == "A pinch of salt")
    }

    @Test func aNumberAloneOnItsLineIsTheNumberOfTheLineAfterIt() {
        // A number in a circle is read from a photo as a line of its own.
        let text = "1\n생강즙 내기: 생강을 갈아 즙을 짭니다.\n향이 은은하게 나도록 준비하세요.\n2\n설탕시럽 만들기: 냄비에 설탕과 물을 끓입니다."
        let steps = StepParser.parse(text)
        #expect(steps.count == 2)
        #expect(steps[0].title == "생강즙 내기: 생강을 갈아 즙을 짭니다")
        #expect(steps[0].detail == "향이 은은하게 나도록 준비하세요.")
        #expect(steps[1].title.hasPrefix("설탕시럽 만들기"))
    }

    @Test func lettersAndRomanNumeralsAloneOnTheirLine() {
        #expect(titles("I\nMix.\nII\nBake.") == ["Mix", "Bake"])
        #expect(titles("a\nMix.\nb\nBake.") == ["Mix", "Bake"])
        #expect(titles("①\nMix.\n②\nBake.") == ["Mix", "Bake"])
    }

    @Test func aNumberWithNoPunctuationNeedsToBeTheNextOne() {
        // "30 grams" wrapped onto a new line is text, not step 30.
        let steps = StepParser.parse("1 Mix the flour with the water and stir until\n30 grams of butter have melted into it.\n2 Bake.")
        #expect(steps.count == 2)
        #expect(steps[0].detail.contains("30 grams of butter"))
    }

    @Test func aDecimalOrATimeIsNotANumber() {
        #expect(titles("1. Mix.\n1.5 cups of milk go in.\n2. Bake.") == ["Mix", "Bake"])
        #expect(titles("1. Mix.\n1:30 is the time.\n2. Bake.") == ["Mix", "Bake"])
    }

    @Test func linesAfterANumberBelongToThatStepAsWritten() {
        let steps = StepParser.parse("1. Roast the Garlic\n• Preheat: Set your oven.\nSlice the tips.\n2. Brown the Meat. Keep the heat high.\n- Sear.")
        #expect(steps.count == 2)
        #expect(steps[0].title == "Roast the Garlic")
        #expect(steps[0].detail == "• Preheat: Set your oven.\nSlice the tips.")
        #expect(steps[1].title == "Brown the Meat")
        #expect(steps[1].detail == "Keep the heat high.\n- Sear.")
    }

    @Test func textWithNoNumberIsNotSteps() {
        #expect(titles("") == [])
        #expect(titles("Mix it") == [])
        #expect(titles("Mix it.\nBake it.\nCool it.") == [])
    }

    @Test func textBeforeTheFirstNumberIsLeftOut() {
        #expect(titles("Directions\n1. Mix.\n2. Bake.") == ["Mix", "Bake"])
    }

    @Test func aPeriodInsideANumberDoesNotEndTheTitle() {
        #expect(titles("1. Add 1.5 cups of milk. Stir.") == ["Add 1.5 cups of milk"])
    }

    @Test func numbersNeedNotStartAtOneOrGoInOrder() {
        #expect(titles("3. Mix.\n1. Bake.\n2. Cool.") == ["Mix", "Bake", "Cool"])
    }

    @Test func aCircleReadAsAnotherSymbolStillStartsAStep() {
        // A circled 16 to 19, as the text reader returned it from a photo.
        let text = """
        ® Lower to low speed.
        ® The meringue becomes glossy and dense.
        (My hand mixer: level 9 - 2 min → level 5 - 2 min → level 3 - 2 min.)
        ® When lifted, the meringue stands firmly but remains slightly soft.
        ® Add part of the meringue to the batter from step ®.
        """
        let steps = StepParser.parse(text)
        #expect(steps.map(\.title) == [
            "Lower to low speed", "The meringue becomes glossy and dense",
            "When lifted, the meringue stands firmly but remains slightly soft",
            "Add part of the meringue to the batter from step ®",
        ])
        #expect(steps[1].detail.contains("My hand mixer"))
    }

    @Test func otherCircleMarksAndCircledLetters() {
        #expect(titles("© Mix.\n@ Bake.") == ["Mix", "Bake"])
        #expect(titles("Ⓐ Mix.\nⓑ Bake.\n⒞ Cool.") == ["Mix", "Bake", "Cool"])
    }

    @Test func aSymbolInTheMiddleOfALineIsNotAStep() {
        #expect(titles("1. Mix with a whisk®.\nthe big one @ the front.") == ["Mix with a whisk®"])
    }
}
