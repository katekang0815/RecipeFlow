//
//  StepParserTests.swift
//  RecipeFlowTests
//

import Testing
@testable import RecipeFlow

/// A step starts at a number, in whatever style the number is written, and is kept as one paragraph.
struct StepParserTests {
    private func steps(_ text: String) -> [String] {
        StepParser.parse(text).map(\.title)
    }

    @Test func plainNumbers() {
        #expect(steps("1. Mix.\n2. Bake.") == ["Mix.", "Bake."])
        #expect(steps("1) Mix.\n2) Bake.") == ["Mix.", "Bake."])
        #expect(steps("1: Mix.\n2: Bake.") == ["Mix.", "Bake."])
        #expect(steps("1、Mix.\n2、Bake.") == ["Mix.", "Bake."])
        #expect(steps("1 Mix.\n2 Bake.") == ["Mix.", "Bake."])
    }

    @Test func parenthesizedNumbers() {
        #expect(steps("(1) Mix.\n(2) Bake.") == ["Mix.", "Bake."])
        #expect(steps("⑴ Mix.\n⑵ Bake.") == ["Mix.", "Bake."])
    }

    @Test func circledNumbers() {
        #expect(steps("① Grind.\n② Heat.\n⑳ Done.") == ["Grind.", "Heat.", "Done."])
        #expect(steps("⒈ Mix.\n⒉ Bake.") == ["Mix.", "Bake."])
        #expect(steps("❶ Mix.\n❷ Bake.") == ["Mix.", "Bake."])
        #expect(steps("➊ Mix.\n➋ Bake.") == ["Mix.", "Bake."])
        #expect(steps("⓫ Mix.\n⓬ Bake.") == ["Mix.", "Bake."])
        #expect(steps("㉑ Mix.\n㉘ Bake.") == ["Mix.", "Bake."])
        #expect(steps("㊱ Mix.\n㊲ Bake.") == ["Mix.", "Bake."])
    }

    @Test func fullWidthDigits() {
        #expect(steps("１．Mix.\n２．Bake.") == ["Mix.", "Bake."])
    }

    @Test func romanNumerals() {
        #expect(steps("I. Mix.\nII. Bake.\nIII. Cool.") == ["Mix.", "Bake.", "Cool."])
        #expect(steps("I) Mix.\nII) Bake.") == ["Mix.", "Bake."])
        #expect(steps("(I) Mix.\n(II) Bake.") == ["Mix.", "Bake."])
    }

    @Test func letters() {
        #expect(steps("a. Mix.\nb. Bake.\nc. Cool.") == ["Mix.", "Bake.", "Cool."])
        #expect(steps("a) Mix.\nb) Bake.") == ["Mix.", "Bake."])
        #expect(steps("(a) Mix.\n(b) Bake.") == ["Mix.", "Bake."])
        #expect(steps("A. Mix.\nB. Bake.") == ["Mix.", "Bake."])
    }

    @Test func aWordIsNotALetterNumber() {
        // "e.g." and an ordinary first word are not numbers.
        #expect(steps("1. Mix with a whisk, e.g.\nthe big one.\n2. A pinch of salt.")
                == ["Mix with a whisk, e.g. the big one.", "A pinch of salt."])
    }

    @Test func aNumberAloneOnItsLineIsTheNumberOfTheLineAfterIt() {
        // A number in a circle is read from a photo as a line of its own.
        let text = "1\n생강즙 내기: 생강을 갈아 즙을 짭니다.\n향이 은은하게 나도록 준비하세요.\n2\n설탕시럽 만들기: 냄비에 설탕과 물을 끓입니다."
        #expect(steps(text) == [
            "생강즙 내기: 생강을 갈아 즙을 짭니다. 향이 은은하게 나도록 준비하세요.",
            "설탕시럽 만들기: 냄비에 설탕과 물을 끓입니다.",
        ])
    }

    @Test func lettersAndRomanNumeralsAloneOnTheirLine() {
        #expect(steps("I\nMix.\nII\nBake.") == ["Mix.", "Bake."])
        #expect(steps("a\nMix.\nb\nBake.") == ["Mix.", "Bake."])
        #expect(steps("①\nMix.\n②\nBake.") == ["Mix.", "Bake."])
    }

    @Test func aNumberWithNoPunctuationNeedsToBeTheNextOne() {
        // "30 grams" wrapped onto a new line is text, not step 30.
        let found = steps("1 Mix the flour with the water and stir until\n30 grams of butter have melted into it.\n2 Bake.")
        #expect(found == ["Mix the flour with the water and stir until 30 grams of butter have melted into it.", "Bake."])
    }

    @Test func aDecimalOrATimeIsNotANumber() {
        #expect(steps("1. Mix.\n1.5 cups of milk go in.\n2. Bake.") == ["Mix. 1.5 cups of milk go in.", "Bake."])
        #expect(steps("1. Mix.\n1:30 is the time.\n2. Bake.") == ["Mix. 1:30 is the time.", "Bake."])
    }

    @Test func aStepIsOneParagraphWithEverythingTheReaderReturned() {
        let text = "1. Roast the Garlic\n• Preheat: Set your oven.\nSlice the tips.\n2. Brown the Meat. Keep the heat high.\n- Sear. (10 minutes D 10:00 )"
        #expect(steps(text) == [
            "Roast the Garlic • Preheat: Set your oven. Slice the tips.",
            "Brown the Meat. Keep the heat high. - Sear. (10 minutes D 10:00 )",
        ])
    }

    @Test func textWithNoNumberIsNotSteps() {
        #expect(steps("") == [])
        #expect(steps("Mix it") == [])
        #expect(steps("Mix it.\nBake it.\nCool it.") == [])
    }

    @Test func textBeforeTheFirstNumberIsLeftOut() {
        #expect(steps("Directions\n1. Mix.\n2. Bake.") == ["Mix.", "Bake."])
    }

    @Test func numbersNeedNotStartAtOneOrGoInOrder() {
        #expect(steps("3. Mix.\n1. Bake.\n2. Cool.") == ["Mix.", "Bake.", "Cool."])
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
        #expect(steps(text) == [
            "Lower to low speed.",
            "The meringue becomes glossy and dense. (My hand mixer: level 9 - 2 min → level 5 - 2 min → level 3 - 2 min.)",
            "When lifted, the meringue stands firmly but remains slightly soft.",
            "Add part of the meringue to the batter from step ®.",
        ])
    }

    @Test func otherCircleMarksAndCircledLetters() {
        #expect(steps("© Mix.\n@ Bake.") == ["Mix.", "Bake."])
        #expect(steps("Ⓐ Mix.\nⓑ Bake.\n⒞ Cool.") == ["Mix.", "Bake.", "Cool."])
    }

    @Test func aSymbolInTheMiddleOfALineIsNotAStep() {
        #expect(steps("1. Mix with a whisk®.\nthe big one @ the front.") == ["Mix with a whisk®. the big one @ the front."])
    }
}
