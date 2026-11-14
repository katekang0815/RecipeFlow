//
//  RecipeFlowUITests.swift
//  RecipeFlowUITests
//
//  Created by Kate Kang on 10/24/26.
//

import XCTest

final class RecipeFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }


    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testAddButtonOpensPasteScreenAndCreatesRecipe() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        snap(app, "1-home")
        app.buttons["Add"].tap()
        let editor = app.textViews["pasteTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))

        let create = app.buttons["Create recipe"]
        snap(app, "2-paste-empty")
        XCTAssertFalse(create.isEnabled, "Create should be disabled while the text is empty")

        editor.tap()
        editor.typeText("Toast\nIngredients: bread")
        XCTAssertTrue(create.isEnabled)
        snap(app, "3-paste-filled")
        create.tap()

        // One ingredient and no steps is only part of a recipe, so the app asks first.
        let createAnyway = app.alerts.buttons["Create anyway"]
        XCTAssertTrue(createAnyway.waitForExistence(timeout: 5))
        snap(app, "3b-partial-warning")
        createAnyway.tap()

        // "Toast" is the title and "bread" the only ingredient; there are no steps.
        XCTAssertTrue(app.staticTexts["bread"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No steps found"].exists)
        snap(app, "4-recipe-flow")
    }

    @MainActor
    func testCreateShowsTheSplitRecipe() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.buttons["Add"].tap()
        let editor = app.textViews["pasteTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("""
        Tangzhong Bread
        Ingredients
        Tangzhong:
        40g bread flour
        200g water

        580g bread flour
        salt to taste
        egg wash (1 egg yolk + milk)
        Directions
        1. Mix flour with water. Stir until thick.
        2. Refrigerate for 6 hours.
        Rest the dough overnight.
        """)
        app.buttons["Create recipe"].tap()

        let title = app.descendants(matching: .any)["recipeTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Tangzhong Bread")
        XCTAssertTrue(app.staticTexts["Tangzhong"].exists, "group heading")
        XCTAssertTrue(app.staticTexts["40 g bread flour"].exists)
        XCTAssertTrue(app.staticTexts["580 g bread flour"].exists)
        XCTAssertTrue(app.staticTexts["salt, to taste"].exists)
        XCTAssertTrue(app.staticTexts["egg wash"].exists)
        XCTAssertTrue(app.staticTexts["1 egg yolk + milk"].exists, "note under the ingredient")
        XCTAssertTrue(app.staticTexts["Mix flour with water"].exists)
        XCTAssertTrue(app.staticTexts["Refrigerate for 6 hours"].exists)
        XCTAssertFalse(app.staticTexts["No steps found"].exists)
        // Text left after the last numbered step goes to the Note section.
        XCTAssertTrue(app.staticTexts["Notes"].exists, "note heading")
        XCTAssertTrue(app.staticTexts["Rest the dough overnight."].exists)
        XCTAssertFalse(app.staticTexts["1 ingredient"].exists)
        snap(app, "5-split-recipe")

        // Back on the home screen the saved recipe is listed, and it opens again.
        app.navigationBars.buttons.firstMatch.tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Tangzhong Bread"))
        XCTAssertTrue(row.label.contains("5 ingredients · 2 steps"))
        snap(app, "7-home-list")
        row.tap()
        XCTAssertTrue(app.staticTexts["40 g bread flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Refrigerate for 6 hours"].exists)
    }

    @MainActor
    func testBulletsStayInsideTheirNumberedStepAndLeftoverTextGoesToTheNote() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.buttons["Add"].tap()
        let editor = app.textViews["pasteTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("""
        Ingredients
        2 cups flour
        1 cup water
        1. Roast the Garlic
        - Preheat: Set your oven to 375F.
        - Prep: Slice the tips off the bulbs.
        2. Brown the Meat
        - Sear: Add the beef.
        Serve with bread.
        """)
        app.buttons["Create recipe"].tap()

        // Only the two numbered lines are steps; the bullets sit inside them.
        XCTAssertTrue(app.staticTexts["Roast the Garlic"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Brown the Meat"].exists)
        XCTAssertFalse(app.staticTexts["Preheat: Set your oven to 375F."].exists, "a bullet is not a step of its own")
        let detail = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Preheat")).firstMatch
        XCTAssertTrue(detail.exists)
        XCTAssertTrue(detail.label.contains("• Prep: Slice the tips off the bulbs."))

        // The leftover line is in the Note, and nothing is listed as ignored.
        XCTAssertTrue(app.staticTexts["Serve with bread."].exists)
        XCTAssertTrue(app.staticTexts["Notes"].exists)
        XCTAssertFalse(app.staticTexts["ignoredLines"].exists)
        snap(app, "11-bulleted-steps-and-note")
    }

    @MainActor
    func testIngredientsOnlyTextCanCreateARecipe() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.buttons["Add"].tap()
        let editor = app.textViews["pasteTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Ingredients\n2 cups flour\n1 cup water\n3 eggs")
        app.buttons["Create recipe"].tap()

        // Part of a recipe: the app says what is missing, then lets the user continue.
        let alert = app.alerts["Check your recipe"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "No numbered steps")).firstMatch.exists)
        snap(app, "12-ingredients-only-warning")
        alert.buttons["Create anyway"].tap()

        XCTAssertTrue(app.staticTexts["2 cups flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["3 eggs"].exists)
        XCTAssertTrue(app.staticTexts["No steps found"].exists)
        XCTAssertFalse(app.staticTexts["No ingredients found"].exists)
        snap(app, "13-ingredients-only-recipe")

        // It is saved, so it is on the home screen.
        app.navigationBars.buttons.firstMatch.tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("3 ingredients · 0 steps"))
    }

    @MainActor
    func testStepsOnlyTextCanCreateARecipe() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.buttons["Add"].tap()
        let editor = app.textViews["pasteTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("1. Mix the flour and water.\n2. Bake for 20 minutes.")
        app.buttons["Create recipe"].tap()

        let alert = app.alerts["Check your recipe"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "No ingredients")).firstMatch.exists)
        snap(app, "14-steps-only-warning")
        alert.buttons["Create anyway"].tap()

        XCTAssertTrue(app.staticTexts["Mix the flour and water"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bake for 20 minutes"].exists)
        XCTAssertTrue(app.staticTexts["No ingredients found"].exists)
        XCTAssertFalse(app.staticTexts["No steps found"].exists)
        snap(app, "15-steps-only-recipe")

        app.navigationBars.buttons.firstMatch.tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("0 ingredients · 2 steps"))
    }

    @MainActor
    func testKeepEditingLeavesTheTextAndCreatesNothing() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.buttons["Add"].tap()
        let editor = app.textViews["pasteTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Ingredients\n2 cups flour\n1 cup water")
        app.buttons["Create recipe"].tap()

        let alert = app.alerts["Check your recipe"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Keep editing"].tap()

        XCTAssertTrue(app.buttons["Create recipe"].waitForExistence(timeout: 5), "still on the paste screen")
        XCTAssertTrue((editor.value as? String ?? "").contains("2 cups flour"), "the text is kept")
        XCTAssertFalse(app.staticTexts["Ingredients"].exists, "no recipe was created")
    }

    /// Starts the app with no saved recipes and creates a recipe from `text`, accepting the partial-recipe popup.
    private func launchWithRecipe(_ text: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.buttons["Add"].tap()
        let editor = app.textViews["pasteTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(text)
        app.buttons["Create recipe"].tap()
        let createAnyway = app.alerts["Check your recipe"].buttons["Create anyway"]
        if createAnyway.waitForExistence(timeout: 3) { createAnyway.tap() }
        return app
    }

    /// Puts the cursor at the end of the text by tapping the empty space below the last line.
    private func tapEnd(of editor: XCUIElement) {
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.95)).tap()
    }

    /// Ends editing a card: the Done button above the keyboard.
    private func tapDone(_ app: XCUIApplication) {
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    }

    /// The text field a card turns into while it is edited: "ingredients", "steps" or "notes".
    private func cardEditor(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.descendants(matching: .any)["\(name)Editor"]
    }

    @MainActor
    func testEveryCardHasAPhotoIconWhetherItIsEmptyOrNot() throws {
        let app = launchWithRecipe("Ingredients\n2 cups flour\n1 cup water\n3 eggs")
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
        snap(app, "16-photo-icon-on-empty-cards")
    }

    @MainActor
    func testThePhotoIconOffersTheLibraryButNoCameraInTheSimulator() throws {
        let app = launchWithRecipe("Ingredients\n2 cups flour\n1 cup water\n3 eggs")
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

    @MainActor
    func testStepsAreAddedByTappingTheEmptyCard() throws {
        let app = launchWithRecipe("Ingredients\n2 cups flour\n1 cup water\n3 eggs")
        XCTAssertTrue(app.staticTexts["No steps found"].waitForExistence(timeout: 5))
        app.staticTexts["No steps found"].tap()

        let editor = cardEditor(app, "steps")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        // Text with no numbered line is not steps, and the card says so.
        editor.typeText("Mix it")
        let message = app.staticTexts["sectionEditorMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue(message.label.contains("No numbered steps found"))

        editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
        editor.typeText("1. Mix the flour and water.\n2. Bake for 20 minutes.")
        XCTAssertTrue(app.staticTexts["2 steps found."].waitForExistence(timeout: 5))
        snap(app, "17-typing-steps-in-the-card")
        tapDone(app)

        XCTAssertTrue(app.staticTexts["Mix the flour and water"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bake for 20 minutes"].exists)
        XCTAssertFalse(app.staticTexts["No steps found"].exists)
        XCTAssertTrue(app.buttons["addStepsPhotoButton"].exists, "the photo icon stays, to add more steps")
        XCTAssertTrue(app.staticTexts["3 eggs"].exists, "the ingredients are untouched")
        snap(app, "18-steps-added")

        app.navigationBars.buttons.firstMatch.tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("3 ingredients · 2 steps"))
    }

    @MainActor
    func testTappingTheStepsEditsThemInPlaceAndOnlyTheStepsAreSaved() throws {
        let app = launchWithRecipe("1. Mix the flour and water.\n2. Bake for 20 minutes.")
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
        snap(app, "19-editing-steps-in-place")
        tapDone(app)

        XCTAssertTrue(app.staticTexts["Cool on a rack"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Mix the flour and water"].exists)
        XCTAssertTrue(app.staticTexts["No ingredients found"].exists, "only the steps were saved")
    }

    @MainActor
    func testIngredientsAreAddedInPlaceWithoutAHeading() throws {
        let app = launchWithRecipe("1. Mix the flour and water.\n2. Bake for 20 minutes.")
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
    func testClearingACardEmptiesItAndBringsBackThePhotoIcon() throws {
        let app = launchWithRecipe("Ingredients\n2 cups flour\n1 cup water\n3 eggs")
        XCTAssertTrue(app.staticTexts["2 cups flour"].waitForExistence(timeout: 5))
        app.staticTexts["2 cups flour"].tap()

        let editor = cardEditor(app, "ingredients")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        tapEnd(of: editor)
        // "2 cups flour" + "1 cup water" + "3 eggs" and two line breaks: 31 characters.
        editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 31))
        tapDone(app)

        XCTAssertTrue(app.staticTexts["No ingredients found"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["addIngredientsPhotoButton"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("0 ingredients · 0 steps"))
    }

    @MainActor
    func testTextWithNothingValidIsNotSaved() throws {
        let app = launchWithRecipe("1. Mix the flour and water.\n2. Bake for 20 minutes.")
        XCTAssertTrue(app.staticTexts["Mix the flour and water"].waitForExistence(timeout: 5))
        app.staticTexts["Mix the flour and water"].tap()

        let editor = cardEditor(app, "steps")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
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
        let app = launchWithRecipe("Ingredients\n2 cups flour\n1 cup water\n3 eggs")
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
        let app = launchWithRecipe("Ingredients\n2 cups flour\n1 cup water\nDirections\n1. Mix the flour and water.\n2. Bake for 20 minutes.")
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
        snap(app, "21-notes-edited-in-place")
    }

    /// Puts the cursor at the end of the title by tapping the right end of its first line.
    private func tapEndOfTitle(_ title: XCUIElement) {
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.1)).tap()
    }

    @MainActor
    func testTheTitleIsEditedByTappingItAndReturnSavesIt() throws {
        let app = launchWithRecipe("Toast\nIngredients\n2 slices bread\n1 tbsp butter\nDirections\n1. Toast it.\n2. Butter it.")
        let title = app.descendants(matching: .any)["recipeTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Toast")
        // No edit icon: the title is the only thing to tap, and no button was added for it.
        XCTAssertFalse(app.buttons["editTitleButton"].exists)

        tapEndOfTitle(title)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5))
        title.typeText("Garlic Toast\n")  // Return finishes editing
        XCTAssertEqual(title.value as? String, "Garlic Toast")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Return closes the keyboard")
        snap(app, "22-title-edited")

        app.navigationBars.buttons.firstMatch.tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Garlic Toast"))
    }

    @MainActor
    func testAnEmptyTitleShowsAHintAndAUntitledRecipeCanBeNamed() throws {
        let app = launchWithRecipe("Ingredients\n2 cups flour\n1 cup water\nDirections\n1. Mix.\n2. Bake.")
        let title = app.descendants(matching: .any)["recipeTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Untitled recipe", "the faded hint")
        snap(app, "23-untitled-hint")

        title.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        title.typeText("Plain Bread\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Plain Bread")

        // Clearing it again brings the hint back, and lists say "Untitled recipe".
        tapEndOfTitle(title)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 11))
        title.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Untitled recipe")
        app.navigationBars.buttons.firstMatch.tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Untitled recipe"))
    }

    @MainActor
    func testSourceLinkCanBeAddedEditedAndRemoved() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.buttons["Add"].tap()
        let editor = app.textViews["pasteTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Toast\nIngredients\n2 slices bread\n1 tbsp butter\nDirections\n1. Toast the bread.\n2. Spread the butter.")
        app.buttons["Create recipe"].tap()
        XCTAssertTrue(app.staticTexts["2 slices bread"].waitForExistence(timeout: 5))
        snap(app, "8-no-source-link")

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
        snap(app, "9-add-source-link")
        save.tap()

        // Saved: the link is shown, and the pencil replaces the +.
        let link = app.descendants(matching: .any)["sourceLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        XCTAssertTrue(link.label.contains("youtube.com/watch?v=abc"))
        XCTAssertFalse(app.buttons["addSourceLinkButton"].exists)
        snap(app, "10-source-link-saved")

        // Edit shows the saved link, and Remove takes it away again.
        app.buttons["editSourceLinkButton"].tap()
        let editField = app.textFields["sourceLinkField"]
        XCTAssertTrue(editField.waitForExistence(timeout: 5))
        XCTAssertTrue((editField.value as? String ?? "").contains("youtube.com/watch?v=abc"))
        app.buttons["removeSourceLinkButton"].tap()
        XCTAssertTrue(app.buttons["addSourceLinkButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["sourceLink"].exists)
    }

    @MainActor
    func testSwipeToDeleteRemovesASavedRecipe() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.buttons["Add"].tap()
        let editor = app.textViews["pasteTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Toast\nIngredients\n2 slices bread\n1 tbsp butter\nDirections\n1. Toast the bread.\n2. Spread the butter.")
        app.buttons["Create recipe"].tap()
        XCTAssertTrue(app.staticTexts["2 slices bread"].waitForExistence(timeout: 5))

        app.navigationBars.buttons.firstMatch.tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        row.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["recipeRow"].exists, "list is empty again")
    }

    @MainActor
    func testCreateTurnsAwayTextThatIsNotARecipe() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.buttons["Add"].tap()
        let editor = app.textViews["pasteTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("The weather was lovely today and we walked along the river for a long time.")
        app.buttons["Create recipe"].tap()

        let message = app.staticTexts["pasteMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue(message.label.contains("doesn't look like an organized recipe"))
        XCTAssertFalse(app.staticTexts["Ingredients"].exists, "the flow page must not open")
        XCTAssertTrue(app.buttons["Create recipe"].exists, "still on the paste screen")
        snap(app, "6-rejected")

        // Editing the text clears the message.
        editor.typeText(" ")
        XCTAssertFalse(message.exists)
    }

    @MainActor
    func testAddPhotoMenuOffersLibraryAndHidesCameraWithoutOne() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.buttons["Add"].tap()
        let addPhoto = app.buttons["addPhotoButton"]
        XCTAssertTrue(addPhoto.waitForExistence(timeout: 5))
        addPhoto.tap()

        XCTAssertTrue(app.buttons["Choose from library"].waitForExistence(timeout: 5))
        snap(app, "5-add-photo-menu")
        // The Simulator has no camera, so the camera choice must not be offered.
        XCTAssertFalse(app.buttons["Take photo"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
