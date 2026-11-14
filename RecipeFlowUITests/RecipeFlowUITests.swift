//
//  RecipeFlowUITests.swift
//  RecipeFlowUITests
//
//  Created by Kate Kang on 10/24/26.
//

import XCTest

final class RecipeFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }

    // MARK: Helpers

    private var checkedKeyboardTip = false

    /// Waits for the keyboard. The first time a keyboard opens on a fresh Simulator it shows a one-time
    /// tip about sliding to type, which covers the keyboard until "Continue" is tapped.
    private func waitForKeyboard(_ app: XCUIApplication) {
        if !checkedKeyboardTip {
            checkedKeyboardTip = true
            let continueButton = app.buttons["Continue"]
            if continueButton.waitForExistence(timeout: 2) { continueButton.tap() }
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Launches with no saved recipes: the tests use a store that lives only in memory.
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()
        return app
    }

    private func titleField(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["recipeTitle"]
    }

    /// The text field a card turns into while it is edited: "ingredients", "steps" or "notes".
    private func cardEditor(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.descendants(matching: .any)["\(name)Editor"]
    }

    /// Ends editing a card: the Done button above the keyboard.
    private func tapDone(_ app: XCUIApplication) {
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    }

    /// Puts the cursor at the end of a card's text by tapping the empty space below the last line.
    private func tapEnd(of editor: XCUIElement) {
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.95)).tap()
    }

    /// Puts the cursor at the end of the title by tapping the right end of its first line.
    private func tapEndOfTitle(_ title: XCUIElement) {
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.1)).tap()
    }

    private func typeTitle(_ app: XCUIApplication, _ text: String) {
        let title = titleField(app)
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        waitForKeyboard(app)
        title.typeText(text + "\n")  // Return finishes editing
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    }

    /// Taps an empty card, types into it, and ends editing.
    private func fill(_ app: XCUIApplication, card name: String, hint: String, with text: String) {
        let empty = app.staticTexts[hint]
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        empty.tap()
        let editor = cardEditor(app, name)
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        waitForKeyboard(app)
        editor.typeText(text)
        tapDone(app)
    }

    /// Starts with no saved recipes, taps Add, and fills in the recipe the way a user does:
    /// by typing into each part of the screen that is given.
    private func launchWithRecipe(
        title: String? = nil,
        ingredients: String? = nil,
        steps: String? = nil,
        notes: String? = nil
    ) -> XCUIApplication {
        let app = launchApp()
        app.buttons["Add"].tap()
        XCTAssertTrue(titleField(app).waitForExistence(timeout: 5))

        if let title { typeTitle(app, title) }
        if let ingredients { fill(app, card: "ingredients", hint: "No ingredients found", with: ingredients) }
        if let steps { fill(app, card: "steps", hint: "No steps found", with: steps) }
        if let notes { fill(app, card: "notes", hint: "No notes yet", with: notes) }
        return app
    }

    // MARK: Launching

    @MainActor
    func testExample() throws {
        _ = launchApp()
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: Adding a recipe

    @MainActor
    func testAddOpensAnEmptyRecipeScreenWithATitleHint() throws {
        let app = launchApp()
        snap(app, "1-home")
        app.buttons["Add"].tap()

        // The title shows "Title", not "Untitled recipe", and every section is empty.
        let title = titleField(app)
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Title")
        XCTAssertFalse(app.staticTexts["Untitled recipe"].exists)
        XCTAssertTrue(app.staticTexts["No ingredients found"].exists)
        XCTAssertTrue(app.staticTexts["No steps found"].exists)
        XCTAssertTrue(app.staticTexts["No notes yet"].exists)
        XCTAssertTrue(app.staticTexts["Add a source link"].exists)

        // A photo icon for each of the three cards, and the source link's own +.
        XCTAssertTrue(app.buttons["addIngredientsPhotoButton"].exists)
        XCTAssertTrue(app.buttons["addStepsPhotoButton"].exists)
        XCTAssertTrue(app.buttons["addNotesPhotoButton"].exists)
        XCTAssertTrue(app.buttons["addSourceLinkButton"].exists)
        snap(app, "2-new-recipe")
    }

    @MainActor
    func testGoingBackFromARecipeThatStayedEmptyKeepsNothing() throws {
        let app = launchApp()
        app.buttons["Add"].tap()
        XCTAssertTrue(titleField(app).waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        // Back on a home screen with no recipes: just the Add button.
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["My recipes"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["recipeRow"].exists)
    }

    @MainActor
    func testARecipeWithJustATitleIsKept() throws {
        let app = launchWithRecipe(title: "Soup")
        app.navigationBars.buttons.firstMatch.tap()

        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Soup"))
        XCTAssertTrue(row.label.contains("0 ingredients · 0 steps"))
    }

    @MainActor
    func testATitleStillBeingTypedWhenGoingBackIsKept() throws {
        let app = launchApp()
        app.buttons["Add"].tap()
        let title = titleField(app)
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        waitForKeyboard(app)
        title.typeText("Soup")  // no Return, no Done
        app.navigationBars.buttons.firstMatch.tap()

        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Soup"))
    }

    @MainActor
    func testTypedCardsShowTheirContentAndTheRecipeIsListed() throws {
        let app = launchWithRecipe(
            title: "Tangzhong Bread",
            ingredients: "Tangzhong:\n40g bread flour\n200g water\n\n580g bread flour\nsalt to taste\negg wash (1 egg yolk + milk)",
            steps: "1. Mix flour with water. Stir until thick.\n2. Refrigerate for 6 hours.",
            notes: "Rest the dough overnight."
        )

        XCTAssertEqual(titleField(app).value as? String, "Tangzhong Bread")
        XCTAssertTrue(app.staticTexts["Tangzhong"].exists, "group heading")
        XCTAssertTrue(app.staticTexts["40 g bread flour"].exists)
        XCTAssertTrue(app.staticTexts["580 g bread flour"].exists)
        XCTAssertTrue(app.staticTexts["salt, to taste"].exists)
        XCTAssertTrue(app.staticTexts["egg wash"].exists)
        XCTAssertTrue(app.staticTexts["1 egg yolk + milk"].exists, "note under the ingredient")
        XCTAssertTrue(app.staticTexts["Mix flour with water"].exists)
        XCTAssertTrue(app.staticTexts["Refrigerate for 6 hours"].exists)
        XCTAssertEqual(app.staticTexts["noteText"].label, "Rest the dough overnight.")
        snap(app, "3-filled-recipe")

        // Back on the home screen the recipe is listed, and it opens again.
        app.navigationBars.buttons.firstMatch.tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Tangzhong Bread"))
        XCTAssertTrue(row.label.contains("5 ingredients · 2 steps"))
        snap(app, "4-home-list")
        row.tap()
        XCTAssertTrue(app.staticTexts["40 g bread flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Refrigerate for 6 hours"].exists)
    }

    @MainActor
    func testBulletsStayInsideTheirNumberedStep() throws {
        let app = launchWithRecipe(
            ingredients: "2 cups flour",
            steps: "1. Roast the Garlic\n- Preheat: Set your oven to 375F.\n- Prep: Slice the tips off the bulbs.\n2. Brown the Meat\n- Sear: Add the beef.",
            notes: "Serve with bread."
        )

        // Only the two numbered lines are steps; the bullets sit inside them.
        XCTAssertTrue(app.staticTexts["Roast the Garlic"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Brown the Meat"].exists)
        XCTAssertFalse(app.staticTexts["Preheat: Set your oven to 375F."].exists, "a bullet is not a step of its own")
        let detail = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Preheat")).firstMatch
        XCTAssertTrue(detail.exists)
        XCTAssertTrue(detail.label.contains("• Prep: Slice the tips off the bulbs."))
        XCTAssertEqual(app.staticTexts["noteText"].label, "Serve with bread.")
        snap(app, "5-bulleted-steps")
    }

    // MARK: The photo icon

    @MainActor
    func testEveryCardHasAPhotoIconWhetherItIsEmptyOrNot() throws {
        let app = launchWithRecipe(ingredients: "2 cups flour\n1 cup water\n3 eggs")
        XCTAssertTrue(app.staticTexts["No steps found"].waitForExistence(timeout: 5))

        // The photo icon is on every card, the filled Ingredients card included, so more can be added later.
        XCTAssertTrue(app.buttons["addStepsPhotoButton"].exists)
        XCTAssertTrue(app.buttons["addNotesPhotoButton"].exists)
        XCTAssertTrue(app.buttons["addIngredientsPhotoButton"].exists)
        for old in ["addStepsButton", "editStepsButton", "addIngredientsButton", "editIngredientsButton", "addNotesButton", "editNotesButton"] {
            XCTAssertFalse(app.buttons[old].exists, old)
        }
        // The source link keeps its own + button.
        XCTAssertTrue(app.buttons["addSourceLinkButton"].exists)
        snap(app, "6-photo-icon-on-every-card")
    }

    @MainActor
    func testThePhotoIconOffersTheLibraryButNoCameraInTheSimulator() throws {
        let app = launchWithRecipe(ingredients: "2 cups flour\n1 cup water\n3 eggs")
        XCTAssertTrue(app.buttons["addStepsPhotoButton"].waitForExistence(timeout: 5))
        app.buttons["addStepsPhotoButton"].tap()

        XCTAssertTrue(app.buttons["Choose from library"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Take photo"].exists, "the Simulator has no camera")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["No steps found"].waitForExistence(timeout: 5))

        // A card that already has content offers the same choices, and cancelling leaves it as it was.
        XCTAssertTrue(app.buttons["addIngredientsPhotoButton"].exists)
        app.buttons["addIngredientsPhotoButton"].tap()
        XCTAssertTrue(app.buttons["Choose from library"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Take photo"].exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["2 cups flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["3 eggs"].exists)
    }

    // MARK: Filling and editing the cards in place

    @MainActor
    func testStepsAreAddedByTappingTheEmptyCard() throws {
        let app = launchWithRecipe(ingredients: "2 cups flour\n1 cup water\n3 eggs")
        XCTAssertTrue(app.staticTexts["No steps found"].waitForExistence(timeout: 5))
        app.staticTexts["No steps found"].tap()

        let editor = cardEditor(app, "steps")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        waitForKeyboard(app)

        // Text with no numbered line is not steps, and the card says so.
        editor.typeText("Mix it")
        let message = app.staticTexts["sectionEditorMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue(message.label.contains("No numbered steps found"))

        editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
        editor.typeText("1. Mix the flour and water.\n2. Bake for 20 minutes.")
        XCTAssertTrue(app.staticTexts["2 steps found."].waitForExistence(timeout: 5))
        snap(app, "7-typing-steps-in-the-card")
        tapDone(app)

        XCTAssertTrue(app.staticTexts["Mix the flour and water"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bake for 20 minutes"].exists)
        XCTAssertFalse(app.staticTexts["No steps found"].exists)
        XCTAssertTrue(app.buttons["addStepsPhotoButton"].exists, "the photo icon stays, to add more steps")
        XCTAssertTrue(app.staticTexts["3 eggs"].exists, "the ingredients are untouched")

        app.navigationBars.buttons.firstMatch.tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("3 ingredients · 2 steps"))
    }

    @MainActor
    func testTappingTheStepsEditsThemInPlaceAndOnlyTheStepsAreSaved() throws {
        let app = launchWithRecipe(steps: "1. Mix the flour and water.\n2. Bake for 20 minutes.")
        XCTAssertTrue(app.staticTexts["Mix the flour and water"].waitForExistence(timeout: 5))
        app.staticTexts["Mix the flour and water"].tap()

        let editor = cardEditor(app, "steps")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        let current = editor.value as? String ?? ""
        XCTAssertTrue(current.contains("1. Mix the flour and water"))
        XCTAssertTrue(current.contains("2. Bake for 20 minutes"))

        // Add a step, and some ingredients that this card must leave out.
        tapEnd(of: editor)
        editor.typeText("\n3. Cool on a rack.\nIngredients\n2 cups flour")
        let message = app.staticTexts["sectionEditorMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue(message.label.contains("3 steps found."))
        XCTAssertTrue(message.label.contains("1 ingredient in this text will not be added."))
        snap(app, "8-editing-steps-in-place")
        tapDone(app)

        XCTAssertTrue(app.staticTexts["Cool on a rack"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Mix the flour and water"].exists)
        XCTAssertTrue(app.staticTexts["No ingredients found"].exists, "only the steps were saved")
    }

    @MainActor
    func testIngredientsAreAddedInPlaceWithoutAHeading() throws {
        let app = launchWithRecipe(steps: "1. Mix the flour and water.\n2. Bake for 20 minutes.")
        XCTAssertTrue(app.staticTexts["No ingredients found"].waitForExistence(timeout: 5))
        app.staticTexts["No ingredients found"].tap()

        let editor = cardEditor(app, "ingredients")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        // No "Ingredients" heading is needed, and a line with no amount counts.
        editor.typeText("salt\n2 cups flour")
        XCTAssertTrue(app.staticTexts["2 ingredients found."].waitForExistence(timeout: 5))
        tapDone(app)

        XCTAssertTrue(app.staticTexts["2 cups flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["salt"].exists)
        XCTAssertTrue(app.buttons["addIngredientsPhotoButton"].exists, "the photo icon stays, to add more")
        XCTAssertTrue(app.staticTexts["Bake for 20 minutes"].exists, "the steps are untouched")
    }

    @MainActor
    func testClearingACardEmptiesItAgain() throws {
        let app = launchWithRecipe(title: "Pancakes", ingredients: "2 cups flour\n1 cup water\n3 eggs")
        XCTAssertTrue(app.staticTexts["2 cups flour"].waitForExistence(timeout: 5))
        app.staticTexts["2 cups flour"].tap()

        let editor = cardEditor(app, "ingredients")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        waitForKeyboard(app)
        tapEnd(of: editor)
        // "2 cups flour" + "1 cup water" + "3 eggs" and two line breaks: 31 characters.
        editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 31))
        tapDone(app)

        XCTAssertTrue(app.staticTexts["No ingredients found"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["addIngredientsPhotoButton"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Pancakes"))
        XCTAssertTrue(row.label.contains("0 ingredients · 0 steps"))
    }

    @MainActor
    func testTextWithNothingValidIsNotSaved() throws {
        let app = launchWithRecipe(steps: "1. Mix the flour and water.\n2. Bake for 20 minutes.")
        XCTAssertTrue(app.staticTexts["Mix the flour and water"].waitForExistence(timeout: 5))
        app.staticTexts["Mix the flour and water"].tap()

        let editor = cardEditor(app, "steps")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        waitForKeyboard(app)
        tapEnd(of: editor)
        // "1. Mix the flour and water" + "2. Bake for 20 minutes" and a line break: 48 characters.
        editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 48))
        editor.typeText("Mix it")
        tapDone(app)

        // It stays on screen with its message instead of replacing the steps.
        XCTAssertTrue(cardEditor(app, "steps").exists)
        XCTAssertTrue(app.staticTexts["sectionEditorMessage"].label.contains("No numbered steps found"))

        // Leaving the screen drops it, and the saved steps are as they were.
        app.navigationBars.buttons.firstMatch.tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("0 ingredients · 2 steps"))
        row.tap()
        XCTAssertTrue(app.staticTexts["Mix the flour and water"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bake for 20 minutes"].exists)
    }

    @MainActor
    func testTappingAnotherCardSavesTheOneBeingEdited() throws {
        let app = launchWithRecipe(ingredients: "2 cups flour\n1 cup water\n3 eggs")
        XCTAssertTrue(app.staticTexts["No steps found"].waitForExistence(timeout: 5))
        app.staticTexts["No steps found"].tap()
        let steps = cardEditor(app, "steps")
        XCTAssertTrue(steps.waitForExistence(timeout: 5))
        steps.typeText("1. Mix the flour and water.\n2. Bake for 20 minutes.")

        // No Done: tap the ingredients card straight away.
        app.staticTexts["2 cups flour"].tap()
        XCTAssertTrue(cardEditor(app, "ingredients").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Mix the flour and water"].waitForExistence(timeout: 5), "the steps were saved")
        XCTAssertFalse(cardEditor(app, "steps").exists)
    }

    @MainActor
    func testNotesAreTypedInPlaceAndSitBetweenStepsAndSourceLink() throws {
        let app = launchWithRecipe(
            ingredients: "2 cups flour\n1 cup water",
            steps: "1. Mix the flour and water.\n2. Bake for 20 minutes."
        )
        XCTAssertTrue(app.staticTexts["Mix the flour and water"].waitForExistence(timeout: 5))

        let steps = app.staticTexts["Steps"], notes = app.staticTexts["Notes"], link = app.staticTexts["Source link"]
        XCTAssertTrue(steps.frame.minY < notes.frame.minY && notes.frame.minY < link.frame.minY, "Notes is between Steps and Source link")
        XCTAssertTrue(app.buttons["addNotesPhotoButton"].exists)
        app.staticTexts["No notes yet"].tap()

        let editor = cardEditor(app, "notes")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.typeText("Rest the dough overnight.")
        tapDone(app)

        // The note is kept as written, and the photo icon stays.
        let card = app.staticTexts["noteText"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertEqual(card.label, "Rest the dough overnight.")
        XCTAssertTrue(app.buttons["addNotesPhotoButton"].exists)

        // Tap the note to edit it, and add a line.
        card.tap()
        let edit = cardEditor(app, "notes")
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertTrue((edit.value as? String ?? "").contains("Rest the dough overnight."))
        tapEnd(of: edit)
        edit.typeText("\nServe warm.")
        tapDone(app)

        let both = app.staticTexts["noteText"]
        XCTAssertTrue(both.waitForExistence(timeout: 5))
        XCTAssertTrue(both.label.contains("Rest the dough overnight."))
        XCTAssertTrue(both.label.contains("Serve warm."))
        snap(app, "9-notes-edited-in-place")
    }

    // MARK: The title

    @MainActor
    func testTheTitleIsEditedByTappingItAndReturnSavesIt() throws {
        let app = launchWithRecipe(title: "Toast", ingredients: "2 slices bread\n1 tbsp butter", steps: "1. Toast it.\n2. Butter it.")
        let title = titleField(app)
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Toast")
        // No edit icon: the title is the only thing to tap, and no button was added for it.
        XCTAssertFalse(app.buttons["editTitleButton"].exists)

        tapEndOfTitle(title)
        waitForKeyboard(app)
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5))
        title.typeText("Garlic Toast\n")  // Return finishes editing
        XCTAssertEqual(title.value as? String, "Garlic Toast")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Return closes the keyboard")
        snap(app, "10-title-edited")

        app.navigationBars.buttons.firstMatch.tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Garlic Toast"))
    }

    @MainActor
    func testAnEmptyTitleShowsTheTitleHintAndCanBeNamedAndClearedAgain() throws {
        let app = launchWithRecipe(ingredients: "2 cups flour\n1 cup water", steps: "1. Mix.\n2. Bake.")
        let title = titleField(app)
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Title", "the faded hint")
        snap(app, "11-title-hint")

        title.tap()
        waitForKeyboard(app)
        title.typeText("Plain Bread\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Plain Bread")

        // Clearing it again brings the hint back, and the list says "Untitled recipe".
        tapEndOfTitle(title)
        waitForKeyboard(app)
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 11))
        title.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Title")
        app.navigationBars.buttons.firstMatch.tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Untitled recipe"))
    }

    // MARK: The source link

    @MainActor
    func testSourceLinkCanBeAddedEditedAndRemoved() throws {
        let app = launchWithRecipe(
            ingredients: "2 slices bread\n1 tbsp butter",
            steps: "1. Toast the bread.\n2. Spread the butter."
        )
        snap(app, "12-no-source-link")

        // No link yet, so the + is shown and not the pencil.
        let add = app.buttons["addSourceLinkButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["editSourceLinkButton"].exists)
        add.tap()

        // The Simulator has no camera, so only pasting is offered.
        let field = app.textFields["sourceLinkField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["takeLinkPhotoButton"].exists)
        let save = app.buttons["saveSourceLinkButton"]
        XCTAssertFalse(save.isEnabled, "nothing to save yet")

        field.tap()
        field.typeText("hello")
        XCTAssertFalse(save.isEnabled)
        XCTAssertTrue(app.staticTexts["sourceLinkMessage"].exists)
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5))
        field.typeText("youtube.com/watch?v=abc")
        XCTAssertTrue(save.isEnabled)
        snap(app, "13-add-source-link")
        save.tap()

        // Saved: the link is shown, and the pencil replaces the +.
        let link = app.descendants(matching: .any)["sourceLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        XCTAssertTrue(link.label.contains("youtube.com/watch?v=abc"))
        XCTAssertFalse(app.buttons["addSourceLinkButton"].exists)
        snap(app, "14-source-link-saved")

        // Edit shows the saved link, and Remove takes it away again.
        app.buttons["editSourceLinkButton"].tap()
        let editField = app.textFields["sourceLinkField"]
        XCTAssertTrue(editField.waitForExistence(timeout: 5))
        XCTAssertTrue((editField.value as? String ?? "").contains("youtube.com/watch?v=abc"))
        app.buttons["removeSourceLinkButton"].tap()
        XCTAssertTrue(app.buttons["addSourceLinkButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["sourceLink"].exists)
    }

    // MARK: The list

    @MainActor
    func testSwipeToDeleteRemovesASavedRecipe() throws {
        let app = launchWithRecipe(
            title: "Toast",
            ingredients: "2 slices bread\n1 tbsp butter",
            steps: "1. Toast the bread.\n2. Spread the butter."
        )
        XCTAssertTrue(app.staticTexts["2 slices bread"].waitForExistence(timeout: 5))

        app.navigationBars.buttons.firstMatch.tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        row.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["recipeRow"].exists, "list is empty again")
    }
}
