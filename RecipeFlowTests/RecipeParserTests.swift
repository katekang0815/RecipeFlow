//
//  RecipeParserTests.swift
//  RecipeFlowTests
//

import Testing
@testable import RecipeFlow

struct RecipeParserTests {
    // MARK: Fixtures

    /// The Tangzhong recipe as it was pasted: steps first, then ingredients, with blank lines.
    private let tangzhong = """
    1. For the Tangzhong, mix 40g bread flour with 200g water in a saute pan. Turn on medium heat and keep stirring until mixture thickens to a paste.
    2. Refrigerate for 6 hours. Bring out to room temperature 1 hour before use.
    3. Add bread flour, sugar, salt, dry yeast, powdered milk to a mixing bowl and mix gently with dough hook attachment.
    4. At low speed, mix in milk and egg and Tangzhong so that no flour is visible.
    5. Add in room temperature unsalted butter and mix at low speed.
    6. Slowly turn up the speed to high and mix until all dough sticks together.
    7. Take the dough and fold it around and underneath itself shaping a smooth ball. Place dough in a bowl, cover with plastic wrap, and let it rest for 40 minutes to
    an hour.
    8. Test the dough by poking your finger down into the middle. If the dough does not spring back, it is ready.
    9. Divide the dough into 6 equal parts (by weight). Take one piece of dough and fold it over itself. Turn it 90 degrees, slap it on table and fold it over itself again.
    Using both hands, mold the dough into a ball. Repeat with rest of dough. Cover with plastic wrap and let it rest for 15 minutes.
    10. Roll each ball of dough out flat. Fold flatten dough using thirds. Turn 90 degrees, and roll dough into a roll, pinching it together at the seam. Place 3 molded
    dough into a baking pan and let it rest for 30 minutes, letting it rise.
    11. Brush with egg wash and bake in the oven, preheated to 355°F for 25-30 minutes.

    Ingredients

    Tangzhong:
    40g  bread flour
    200g water

    580g bread flour
    60g  sugar
    12g  salt
    10g  dry yeast
    10g  dry milk
    260g milk
    50g  egg
    Tangzhong
    50g  room temperature of unsalted butter
    egg wash (1 egg yolk + milk)
    """

    /// What OCR actually returned: no blank lines, degree sign dropped.
    private let tangzhongFromOCR = """
    9. Divide the dough into 6 equal parts (by weight). Take one piece of dough and fold it
    over itself. Turn it 90 degrees, slap it on table
    and fold it over itself again.
    Using both hands, mold the dough into a ball.
    Repeat with rest of dough. Cover with plastic
    wrap and let it rest for 15 minutes.
    10. Roll each ball of dough out flat. Fold flatten
    dough using thirds. Turn 90 degrees, and roll
    dough into a roll, pinching it together at the
    seam. Place 3 molded
    dough into a baking pan and let it rest for 30
    minutes, letting it rise.
    11. Brush with egg wash and bake in the oven,
    preheated to 355F for 25-30 minutes.
    Ingredients
    Tangzhong:
    40g bread flour
    200g water
    580g bread flour
    60g sugar
    12g salt
    10g dry yeast
    10g dry milk
    260g milk
    50g egg
    Tangzhong
    50g room temperature of unsalted butter
    egg wash (1 egg yolk + milk)
    """

    // MARK: Your Tangzhong recipe

    @Test func splitsTheTangzhongRecipe() {
        let recipe = RecipeParser.parse(tangzhong)
        #expect(recipe.steps.count == 11)
        #expect(recipe.ingredients.count == 12)
        #expect(recipe.ignoredLines.isEmpty)
    }

    @Test func tangzhongIngredientsKeepQuantityUnitAndGroup() {
        let items = RecipeParser.parse(tangzhong).ingredients
        #expect(items[0] == ParsedIngredient(quantity: "40", unit: "g", name: "bread flour", group: "Tangzhong"))
        #expect(items[1] == ParsedIngredient(quantity: "200", unit: "g", name: "water", group: "Tangzhong"))
        // The blank line ends the Tangzhong group.
        #expect(items[2] == ParsedIngredient(quantity: "580", unit: "g", name: "bread flour", group: nil))
        #expect(items[4].name == "salt")
        #expect(items[8] == ParsedIngredient(quantity: "50", unit: "g", name: "egg", group: nil))
    }

    @Test func bareTangzhongLineStaysAnIngredientWithNoQuantity() {
        let items = RecipeParser.parse(tangzhong).ingredients
        #expect(items[9] == ParsedIngredient(quantity: "", unit: "", name: "Tangzhong", group: nil))
        #expect(items[10].name == "room temperature of unsalted butter")
    }

    @Test func parenthesesBecomeANote() {
        let last = RecipeParser.parse(tangzhong).ingredients[11]
        #expect(last.name == "egg wash")
        #expect(last.quantity == "")
        #expect(last.note == "1 egg yolk + milk")
    }

    @Test func wrappedLinesJoinTheirStep() {
        let steps = RecipeParser.parse(tangzhong).steps
        #expect(steps[6].detail.hasSuffix("let it rest for 40 minutes to an hour."))
        #expect(steps[8].detail.contains("Using both hands, mold the dough into a ball."))
        #expect(steps[9].detail.contains("Place 3 molded dough into a baking pan"))
    }

    @Test func stepTitleIsTheFirstSentence() {
        let first = RecipeParser.parse(tangzhong).steps[0]
        #expect(first.title == "For the Tangzhong, mix 40g bread flour with 200g water in a saute pan")
        #expect(first.detail == "Turn on medium heat and keep stirring until mixture thickens to a paste.")
        #expect(RecipeParser.parse(tangzhong).steps[4].detail == "")
    }

    @Test func ocrOutputWithoutBlankLinesStillSplitsCorrectly() {
        let recipe = RecipeParser.parse(tangzhongFromOCR)
        #expect(recipe.steps.count == 3)
        #expect(recipe.ingredients.count == 12)
        #expect(recipe.steps[2].title == "Brush with egg wash and bake in the oven, preheated to 355F for 25-30 minutes")
        #expect(recipe.steps[0].detail.contains("Using both hands, mold the dough into a ball. Repeat with rest of dough."))
        // OCR drops the blank line, so the repeated "bread flour" is what ends the group.
        #expect(recipe.ingredients[0].group == "Tangzhong")
        #expect(recipe.ingredients[1].group == "Tangzhong")
        #expect(recipe.ingredients[2].group == nil)
        #expect(recipe.ingredients[8].group == nil)
    }

    // MARK: Quantities and units

    @Test func readsFractionsRangesAndDecimals() {
        let recipe = RecipeParser.parse("""
        Ingredients
        1 1/2 cups milk
        ½ tsp salt
        2-3 cloves garlic
        1.5 kg potatoes
        1/4 cup sugar
        """)
        #expect(recipe.steps.isEmpty)
        #expect(recipe.ingredients.map(\.quantity) == ["1 1/2", "½", "2-3", "1.5", "1/4"])
        #expect(recipe.ingredients.map(\.unit) == ["cups", "tsp", "cloves", "kg", "cup"])
        #expect(recipe.ingredients.map(\.name) == ["milk", "salt", "garlic", "potatoes", "sugar"])
    }

    @Test func unitCanBeAttachedOrSeparate() {
        let items = RecipeParser.parse("Ingredients\n40g flour\n40 g sugar\n2 eggs").ingredients
        #expect(items.map(\.unit) == ["g", "g", ""])
        #expect(items.map(\.name) == ["flour", "sugar", "eggs"])
    }

    @Test func commaAfterTheNameBecomesANote() {
        let item = RecipeParser.parse("Ingredients\n2 eggs, beaten").ingredients[0]
        #expect(item.name == "eggs")
        #expect(item.note == "beaten")
    }

    @Test func qualitativeAmounts() {
        let items = RecipeParser.parse("Ingredients\nsalt to taste\n소금 약간").ingredients
        #expect(items[0] == ParsedIngredient(quantity: "to taste", unit: "", name: "salt"))
        #expect(items[1] == ParsedIngredient(quantity: "약간", unit: "", name: "소금"))
    }

    @Test func decimalIsNotMistakenForAStepNumber() {
        let recipe = RecipeParser.parse("Ingredients\n1.5 cups flour\nDirections\n1. Mix.")
        #expect(recipe.ingredients.count == 1)
        #expect(recipe.ingredients[0].quantity == "1.5")
        #expect(recipe.steps.count == 1)
    }

    // MARK: Layout variations

    @Test func unnumberedSentencesUnderDirectionsAreNotSteps() {
        let recipe = RecipeParser.parse("""
        Ingredients
        2 slices bread
        1 tbsp butter

        Directions
        Toast the bread.
        Spread the butter on top.
        """)
        #expect(recipe.ingredients.count == 2)
        #expect(recipe.steps.isEmpty)
        #expect(recipe.note.isEmpty)
        #expect(recipe.ignoredLines == ["Toast the bread.", "Spread the butter on top."])
    }

    @Test func noHeadersAtAll() {
        let recipe = RecipeParser.parse("""
        Toast
        2 slices bread
        1 tbsp butter
        1. Toast the bread.
        2. Spread the butter.
        """)
        #expect(recipe.title == "Toast")
        #expect(recipe.ingredients.count == 2)
        #expect(recipe.steps.count == 2)
    }

    @Test func headerWithContentOnTheSameLine() {
        let recipe = RecipeParser.parse("Toast\nIngredients: bread")
        #expect(recipe.title == "Toast")
        #expect(recipe.ingredients == [ParsedIngredient(quantity: "", unit: "", name: "bread")])
    }

    @Test func stepsFirstThenIngredientsWithoutAHeader() {
        let recipe = RecipeParser.parse("""
        1. Mix the flour and water.
        2. Bake for 20 minutes.
        200 g flour
        100 ml water
        """)
        #expect(recipe.steps.count == 2)
        #expect(recipe.ingredients.map(\.name) == ["flour", "water"])
    }

    @Test func numberedLinesInAnIngredientListStayIngredients() {
        let recipe = RecipeParser.parse("Ingredients\n1. 2 cups flour\n2. 1 cup sugar\nSteps\n1. Mix.")
        #expect(recipe.ingredients.count == 2)
        #expect(recipe.steps.count == 1)
    }

    @Test func otherNumberingAndBulletStyles() {
        let recipe = RecipeParser.parse("""
        Ingredients
        • 2 cups flour
        - 1 cup sugar
        Method
        Step 1: Mix everything.
        2) Bake it.
        ③ Let it cool.
        """)
        #expect(recipe.ingredients.map(\.name) == ["flour", "sugar"])
        #expect(recipe.steps.map(\.title) == ["Mix everything", "Bake it", "Let it cool"])
    }

    @Test func windowsLineEndings() {
        let recipe = RecipeParser.parse("Ingredients\r\n2 cups flour\r\nSteps\r\n1. Mix.\r\n")
        #expect(recipe.ingredients.count == 1)
        #expect(recipe.steps.count == 1)
    }

    @Test func durationAtTheStartOfAWrappedLineIsNotAnIngredient() {
        let recipe = RecipeParser.parse("""
        1. Let the dough rest for
        40 minutes to an hour.
        2. Bake.
        """)
        #expect(recipe.steps.count == 2)
        #expect(recipe.ingredients.isEmpty)
        #expect(recipe.steps[0].title == "Let the dough rest for 40 minutes to an hour")
    }

    // MARK: Ingredients section

    @Test func ingredientsAreEverythingBetweenTheHeaderAndTheFirstStep() {
        let recipe = RecipeParser.parse("""
        Ingredients
        2 cups flour
        1 cup sugar
        pinch of love
        1. Mix.
        2. Bake.
        """)
        #expect(recipe.ingredients.map(\.name) == ["flour", "sugar", "pinch of love"])
        #expect(recipe.steps.count == 2)
        // The header itself is not an ingredient.
        #expect(!recipe.ingredients.contains { $0.name.lowercased() == "ingredients" })
    }

    @Test func koreanHeaderIsNotAnIngredientEither() {
        let recipe = RecipeParser.parse("재료\n밥 2공기\n김치 1컵\n1. 볶는다.\n2. 먹는다.")
        #expect(recipe.ingredients.map(\.name) == ["밥", "김치"])
        #expect(recipe.steps.count == 2)
    }

    @Test func everythingUnderTheHeaderIsAnIngredientWhenTheStepsCameFirst() {
        let recipe = RecipeParser.parse("""
        1. Mix.
        2. Bake.
        Ingredients
        2 cups flour
        salt
        a long line that is not really an ingredient but sits under the header anyway
        """)
        #expect(recipe.steps.count == 2)
        #expect(recipe.ingredients.count == 3)
        #expect(recipe.ingredients[2].name == "a long line that is not really an ingredient but sits under the header anyway")
        #expect(recipe.note.isEmpty)
    }

    // MARK: Steps section

    @Test func stepsMustBeNumbered() {
        let recipe = RecipeParser.parse("""
        Ingredients
        2 cups flour
        Steps
        Mix the flour.
        1. Bake it.
        """)
        #expect(recipe.steps.map(\.title) == ["Bake it"])
        #expect(recipe.ignoredLines == ["Mix the flour."])
    }

    @Test func numberingNeedNotStartAtOne() {
        // A cropped photo can begin in the middle of a recipe.
        let recipe = RecipeParser.parse("9. Mix.\n10. Bake.\n11. Cool.")
        #expect(recipe.steps.map(\.title) == ["Mix", "Bake", "Cool"])
    }

    @Test func aSecondListThatRestartsAtOneContinuesTheSteps() {
        let recipe = RecipeParser.parse("""
        Dough
        1. Mix flour.
        2. Rest it.
        Filling
        1. Chop apples.
        2. Cook them.
        """)
        #expect(recipe.steps.map(\.title) == ["Mix flour", "Rest it", "Chop apples", "Cook them"])
    }

    @Test func aNumberThatGoesBackwardsIsNotAStep() {
        let recipe = RecipeParser.parse("1. Mix.\n2. Bake.\n3. Cool.\n2. stray line.")
        #expect(recipe.steps.map(\.title) == ["Mix", "Bake", "Cool"])
    }

    @Test func linesBetweenTwoNumberedStepsBelongToTheEarlierOne() {
        let recipe = RecipeParser.parse("""
        1. Mix the flour.
        Then wait a little.
        Keep it warm.
        2. Bake it.
        """)
        #expect(recipe.steps.count == 2)
        #expect(recipe.steps[0].detail == "Then wait a little. Keep it warm.")
        #expect(recipe.note.isEmpty)
    }

    // MARK: Note section

    @Test func textAfterTheLastNumberedStepIsTheNote() {
        let recipe = RecipeParser.parse("""
        1. Mix.
        2. Bake for 20 minutes.
        Keep leftovers in the fridge.
        Eat within three days.
        """)
        #expect(recipe.steps.count == 2)
        #expect(recipe.note == ["Keep leftovers in the fridge.", "Eat within three days."])
        #expect(recipe.steps[1].title == "Bake for 20 minutes")
    }

    @Test func aWrappedLastStepIsNotANote() {
        let recipe = RecipeParser.parse("1. Mix.\n2. Bake it in the oven for\n20 minutes.")
        #expect(recipe.steps.count == 2)
        #expect(recipe.steps[1].title == "Bake it in the oven for 20 minutes")
        #expect(recipe.note.isEmpty)
    }

    @Test func anExplicitNoteHeaderStartsTheNote() {
        let recipe = RecipeParser.parse("""
        1. Mix.
        2. Bake.
        Notes
        Rest the dough overnight.
        1. this numbered line stays in the note
        """)
        #expect(recipe.steps.count == 2)
        #expect(recipe.note == ["Rest the dough overnight.", "1. this numbered line stays in the note"])
    }

    @Test func noteHeaderWithTextOnTheSameLine() {
        let recipe = RecipeParser.parse("1. Mix.\n2. Bake.\nNote: rest the dough overnight")
        #expect(recipe.note == ["rest the dough overnight"])
    }

    @Test func koreanNoteHeaders() {
        let recipe = RecipeParser.parse("1. 볶는다.\n2. 먹는다.\n참고\n밥은 식힌 것을 쓴다.")
        #expect(recipe.note == ["밥은 식힌 것을 쓴다."])
        let memo = RecipeParser.parse("1. 볶는다.\n2. 먹는다.\n메모: 소금은 취향껏")
        #expect(memo.note == ["소금은 취향껏"])
    }

    @Test func ingredientsAfterANoteStillWork() {
        let recipe = RecipeParser.parse("""
        1. Mix.
        2. Bake.
        Note: rest the dough
        Ingredients
        2 cups flour
        1 cup water
        """)
        #expect(recipe.note == ["rest the dough"])
        #expect(recipe.ingredients.count == 2)
        #expect(recipe.steps.count == 2)
    }

    @Test func tangzhongHasNoNote() {
        #expect(RecipeParser.parse(tangzhong).note.isEmpty)
        #expect(RecipeParser.parse(tangzhongFromOCR).note.isEmpty)
    }

    // MARK: Korean

    @Test func koreanRecipe() {
        let recipe = RecipeParser.parse("""
        김치볶음밥
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
        """)
        #expect(recipe.title == "김치볶음밥")
        #expect(recipe.ingredients == [
            ParsedIngredient(quantity: "2", unit: "공기", name: "밥"),
            ParsedIngredient(quantity: "1", unit: "컵", name: "김치"),
            ParsedIngredient(quantity: "2", unit: "개", name: "계란"),
            ParsedIngredient(quantity: "약간", unit: "", name: "소금"),
            ParsedIngredient(quantity: "1", unit: "큰술", name: "간장", group: "양념"),
        ])
        #expect(recipe.steps.map(\.title) == [
            "팬에 기름을 두르고 김치를 볶는다",
            "밥을 넣고 함께 볶는다",
            "계란 프라이를 올린다",
        ])
    }

    @Test func koreanBracketedHeadersAndGroups() {
        let recipe = RecipeParser.parse("""
        [재료]
        돼지고기 300g
        [양념장]
        고추장 2큰술
        [만드는 법]
        ① 고기를 재운다.
        ② 팬에 볶는다.
        """)
        #expect(recipe.ingredients.count == 2)
        #expect(recipe.ingredients[0].group == nil)
        #expect(recipe.ingredients[1] == ParsedIngredient(quantity: "2", unit: "큰술", name: "고추장", group: "양념장"))
        #expect(recipe.steps.count == 2)
    }

    // MARK: Unrelated text

    @Test func noiseLinesAreSetAside() {
        let recipe = RecipeParser.parse("""
        Advertisement
        Ingredients
        2 cups flour
        www.example.com/pizza
        12
        Directions
        1. Mix.
        """)
        #expect(recipe.ingredients.count == 1)
        #expect(recipe.steps.count == 1)
        #expect(recipe.ignoredLines == ["Advertisement", "www.example.com/pizza", "12"])
    }

    @Test func proseGivesNothing() {
        let recipe = RecipeParser.parse("""
        The weather was lovely today and we walked along the river for a long time.
        Afterwards we sat down and talked about everything that had happened this year.
        """)
        #expect(recipe.ingredients.isEmpty)
        #expect(recipe.steps.isEmpty)
        #expect(recipe.title == nil)
        #expect(recipe.ignoredLines.count == 2)
    }

    @Test func emptyAndWhitespaceInput() {
        #expect(RecipeParser.parse("") == ParsedRecipe())
        #expect(RecipeParser.parse("  \n\n \t ") == ParsedRecipe())
    }
}
