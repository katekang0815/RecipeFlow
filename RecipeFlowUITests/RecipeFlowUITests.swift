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
    /// `photoText` is what a photo of each section "contains" (keys "ingredients", "steps", "notes"),
    /// since the system photo picker and the camera cannot be driven from a test.
    private func launchApp(photoText: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-fakePhoto"]
        for (section, text) in photoText {
            app.launchArguments += ["-fakePhotoText.\(section)", text.replacingOccurrences(of: "\n", with: "⏎")]
        }
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

    /// Ends editing a card with the check button.
    private func tapDone(_ app: XCUIApplication) {
        // The check button saves the same way as a tap outside the cards, which has a test of its own.
        app.buttons["checkButton"].tap()
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

    /// Adds a section from the plus on the recipe screen: the plus, the section, then a photo from the
    /// library. The section opens for checking with the photo's text in it. "Ingredients", "Steps", "Notes".
    private func addSection(_ app: XCUIApplication, _ name: String) {
        let plus = app.buttons["addSectionButton"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5))
        plus.tap()
        let option = app.buttons[name]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        let library = app.buttons["Choose from library"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        library.tap()
        XCTAssertTrue(cardEditor(app, name.lowercased()).waitForExistence(timeout: 5))
    }

    /// Adds a section from a photo and saves it by closing the keyboard.
    private func fill(_ app: XCUIApplication, _ name: String) {
        addSection(app, name)
        waitForKeyboard(app)
        tapDone(app)
    }

    /// Adds a recipe card from the home screen: the plus, then a picture from the library.
    private func addCard(_ app: XCUIApplication) {
        let add = app.buttons["addRecipeButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let library = app.buttons["Choose from library"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        library.tap()
        // A library picture is cropped first, like a camera photo.
        let use = app.buttons["usePhotoButton"]
        XCTAssertTrue(use.waitForExistence(timeout: 5), "the crop screen")
        use.tap()
        XCTAssertTrue(app.buttons["recipeRow"].firstMatch.waitForExistence(timeout: 5))
    }

    /// Adds a recipe card and opens it.
    private func openNewRecipe(_ app: XCUIApplication) {
        addCard(app)
        app.buttons["recipeRow"].firstMatch.tap()
        XCTAssertTrue(titleField(app).waitForExistence(timeout: 5))
    }

    /// Starts with no saved recipes, adds a card with a picture, opens it, and fills in the recipe
    /// the way a user does: the title by typing, each section from a photo.
    private func launchWithRecipe(
        title: String? = nil,
        ingredients: String? = nil,
        steps: String? = nil,
        notes: String? = nil
    ) -> XCUIApplication {
        var photoText: [String: String] = [:]
        if let ingredients { photoText["ingredients"] = ingredients }
        if let steps { photoText["steps"] = steps }
        if let notes { photoText["notes"] = notes }
        let app = launchApp(photoText: photoText)
        openNewRecipe(app)

        if let title { typeTitle(app, title) }
        if ingredients != nil { fill(app, "Ingredients") }
        if steps != nil { fill(app, "Steps") }
        if notes != nil { fill(app, "Notes") }
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
    func testTheEmptyHomeScreenHasJustAPlusAndItAsksForAThumbnail() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["My Recipes"].exists)
        XCTAssertFalse(app.buttons["recipeRow"].exists)
        snap(app, "1-home")

        app.buttons["addRecipeButton"].tap()
        XCTAssertTrue(app.staticTexts["Add a thumbnail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Choose from library"].exists)
        // Backing out adds nothing.
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.buttons["recipeRow"].exists)
    }

    @MainActor
    func testAPictureMakesACardAndTappingTheCardOpensAnEmptyRecipe() throws {
        let app = launchApp()
        addCard(app)
        // Adding the picture stays on the home screen, and the plus moves after the card.
        XCTAssertFalse(titleField(app).exists)
        XCTAssertTrue(app.buttons["addRecipeButton"].exists)
        snap(app, "2-home-with-card")

        app.buttons["recipeRow"].firstMatch.tap()
        let title = titleField(app)
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Add Title")

        // No sections yet: just the one plus.
        for heading in ["Ingredients", "Steps", "Notes", "Source link"] {
            XCTAssertFalse(app.staticTexts[heading].exists, heading)
        }
        XCTAssertTrue(app.buttons["addSectionButton"].exists)
        snap(app, "3-new-recipe")
    }

    @MainActor
    func testEachNewPictureAddsAnotherCard() throws {
        let app = launchApp()
        addCard(app)
        addCard(app)
        XCTAssertEqual(app.buttons.matching(identifier: "recipeRow").count, 2)
    }

    @MainActor
    func testARecipeWithJustATitleIsKept() throws {
        let app = launchWithRecipe(title: "Soup")
        app.buttons["backButton"].tap()

        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Soup"))
        XCTAssertTrue(row.label.contains("0 ingredients · 0 steps"))
    }

    @MainActor
    func testATitleStillBeingTypedWhenGoingBackIsKept() throws {
        let app = launchApp()
        openNewRecipe(app)
        let title = titleField(app)
        title.tap()
        waitForKeyboard(app)
        title.typeText("Soup")  // no Return, no Done
        app.buttons["backButton"].tap()

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
        // Ingredients are kept as written, one line each.
        for line in ["Tangzhong:", "40g bread flour", "200g water", "580g bread flour", "salt to taste", "egg wash (1 egg yolk + milk)"] {
            XCTAssertTrue(app.staticTexts[line].exists, line)
        }
        XCTAssertTrue(app.staticTexts["Mix flour with water. Stir until thick."].exists)
        XCTAssertTrue(app.staticTexts["Refrigerate for 6 hours."].exists)
        XCTAssertEqual(app.staticTexts["noteText"].label, "Rest the dough overnight.")
        snap(app, "3-filled-recipe")

        // Back on the home screen the recipe is listed, and it opens again.
        app.buttons["backButton"].tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Tangzhong Bread"))
        XCTAssertTrue(row.label.contains("6 ingredients · 2 steps"))
        snap(app, "4-home-list")
        row.tap()
        XCTAssertTrue(app.staticTexts["40g bread flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Refrigerate for 6 hours."].exists)
    }

    @MainActor
    func testBulletsStayInsideTheirNumberedStep() throws {
        let app = launchWithRecipe(
            ingredients: "2 cups flour",
            steps: "1. Roast the Garlic\n- Preheat: Set your oven to 375F.\n- Prep: Slice the tips off the bulbs.\n2. Brown the Meat\n- Sear: Add the beef.",
            notes: "Serve with bread."
        )

        // Only the two numbered lines are steps; the lines under them stay in the same paragraph, as written.
        XCTAssertTrue(app.staticTexts["Roast the Garlic - Preheat: Set your oven to 375F. - Prep: Slice the tips off the bulbs."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Brown the Meat - Sear: Add the beef."].exists)
        XCTAssertEqual(app.staticTexts["noteText"].label, "Serve with bread.")
        snap(app, "5-bulleted-steps")
    }

    // MARK: The plus

    @MainActor
    func testThePlusIsHiddenWhileTheKeyboardIsUp() throws {
        let app = launchWithRecipe(ingredients: "2 cups flour\n1 cup water\n3 eggs")
        let plus = app.buttons["addSectionButton"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5))

        // A section being edited.
        app.staticTexts["3 eggs"].tap()
        XCTAssertTrue(cardEditor(app, "ingredients").waitForExistence(timeout: 5))
        waitForKeyboard(app)
        XCTAssertTrue(plus.waitForNonExistence(timeout: 5))
        snap(app, "15-no-plus-while-typing")
        tapDone(app)
        XCTAssertTrue(plus.waitForExistence(timeout: 5))

        // The title being edited.
        app.descendants(matching: .any)["recipeTitle"].firstMatch.tap()
        waitForKeyboard(app)
        XCTAssertTrue(plus.waitForNonExistence(timeout: 5))
        app.typeText("\n")
        XCTAssertTrue(plus.waitForExistence(timeout: 5))
    }

    @MainActor
    func testThePlusPullsUpTheFourSections() throws {
        let app = launchWithRecipe(ingredients: "2 cups flour\n1 cup water\n3 eggs")
        app.buttons["addSectionButton"].tap()
        for option in ["Ingredients", "Steps", "Notes", "Source link"] {
            XCTAssertTrue(app.buttons[option].waitForExistence(timeout: 5), option)
        }
        snap(app, "6-plus-menu")
        // No other add buttons are left on the page.
        for old in ["addIngredientsPhotoButton", "addStepsPhotoButton", "addNotesPhotoButton", "addSourceLinkButton"] {
            XCTAssertFalse(app.buttons[old].exists, old)
        }
        app.buttons["cancelChoicesButton"].tap()
        XCTAssertTrue(app.buttons["Source link"].waitForNonExistence(timeout: 5), "Cancel puts the sheet away")
        XCTAssertFalse(app.staticTexts["Steps"].exists, "nothing was added")
    }

    @MainActor
    func testSectionsKeepTheirOrderAndThePlusStaysBelowThem() throws {
        let app = launchApp(photoText: [
            "ingredients": "2 cups flour\n1 cup water",
            "steps": "1. Mix the flour and water.\n2. Bake for 20 minutes.",
            "notes": "Rest the dough overnight.",
        ])
        openNewRecipe(app)
        let plus = app.buttons["addSectionButton"]

        // Steps first: it appears, and the plus moves below it.
        let plusBefore = plus.frame.minY
        fill(app, "Steps")
        XCTAssertTrue(app.staticTexts["Mix the flour and water."].waitForExistence(timeout: 5))
        XCTAssertTrue(plus.frame.minY > plusBefore)
        XCTAssertTrue(plus.frame.minY > app.staticTexts["Bake for 20 minutes."].frame.maxY)

        // Ingredients next: it goes above Steps, and the plus is still at the bottom.
        fill(app, "Ingredients")
        XCTAssertTrue(app.staticTexts["2 cups flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ingredients"].frame.minY < app.staticTexts["Steps"].frame.minY)
        XCTAssertTrue(plus.frame.minY > app.staticTexts["Bake for 20 minutes."].frame.maxY)

        fill(app, "Notes")
        XCTAssertTrue(app.staticTexts["noteText"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Steps"].frame.minY < app.staticTexts["Notes"].frame.minY)
        XCTAssertTrue(plus.frame.minY > app.staticTexts["noteText"].frame.maxY)
        snap(app, "7-sections-in-order")
    }

    @MainActor
    func testAPhotoOfferedForASectionCanBeCancelledAndAddsNothing() throws {
        let app = launchWithRecipe(ingredients: "2 cups flour\n1 cup water\n3 eggs")
        app.buttons["addSectionButton"].tap()
        app.buttons["Steps"].tap()

        XCTAssertTrue(app.buttons["Choose from library"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Take photo"].exists, "the Simulator has no camera")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["2 cups flour"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Steps"].exists, "cancelling adds no section")
    }

    @MainActor
    func testPhotoStepsWithNoNumbersAreNotAddedAndAnAlertSaysWhy() throws {
        let app = launchApp(photoText: ["steps": "Mix the flour.\nBake it until golden.\nCool it."])
        openNewRecipe(app)
        app.buttons["addSectionButton"].tap()
        XCTAssertTrue(app.buttons["Steps"].waitForExistence(timeout: 5))
        app.buttons["Steps"].tap()
        let library = app.buttons["Choose from library"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        sleep(1)  // let the choices finish sliding in before tapping one
        library.tap()

        // The photo is read first, which takes a moment: look once a second.
        var shown = false
        for _ in 0..<30 {
            if app.alerts.count > 0 { shown = true; break }
            sleep(1)
        }
        XCTAssertTrue(shown, "the alert did not appear")
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.staticTexts["Only numbered steps are valid"].exists, alert.debugDescription)
        alert.buttons["OK"].tap()
        XCTAssertFalse(app.staticTexts["Steps"].exists, "nothing was added")
        XCTAssertFalse(cardEditor(app, "steps").exists)
    }

    @MainActor
    func testReturnInTheMiddleOfAStepStartsTheNextStepThere() throws {
        let app = launchApp(photoText: ["steps": "1. Mix the flour.\n2. Bake it. Cool it."])
        openNewRecipe(app)
        fill(app, "Steps")
        app.staticTexts["Bake it. Cool it."].tap()

        let editor = cardEditor(app, "steps")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        waitForKeyboard(app)
        // Put the cursor inside the second line, then press Return there.
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.7)).tap()
        editor.typeText("\n")
        sleep(1)

        let lines = (editor.value as? String ?? "").components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 3, "the second step was split in two: \(lines)")
        XCTAssertEqual(lines.first, "1. Mix the flour.")
        XCTAssertTrue(lines.count == 3 && lines[1].count > 3 && lines[2].count > 3, "split inside the line, not at its end: \(lines)")
        XCTAssertTrue(lines.count == 3 && lines[1].hasPrefix("2. ") && lines[2].hasPrefix("3. "), "\(lines)")
        if lines.count == 3 {
            let joined = lines[1].dropFirst(3) + " " + lines[2].dropFirst(3)
            XCTAssertEqual(joined.trimmingCharacters(in: .whitespaces), "Bake it. Cool it.")
        }
        XCTAssertFalse(app.staticTexts["sectionEditorMessage"].exists, "no message under valid steps")
        tapDone(app)

        XCTAssertTrue(app.staticTexts["3"].waitForExistence(timeout: 5), "three steps")
    }

    @MainActor
    func testReturnAtTheEndOfTheStepsMakesTheNextNumberToTypeInto() throws {
        let app = launchApp(photoText: ["steps": "1. Mix the flour.\n2. Bake it."])
        openNewRecipe(app)
        fill(app, "Steps")
        app.staticTexts["Bake it."].tap()

        let editor = cardEditor(app, "steps")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        waitForKeyboard(app)
        tapEnd(of: editor)
        editor.typeText("\n")
        sleep(1)
        editor.typeText("Cool it.")
        XCTAssertEqual(editor.value as? String, "1. Mix the flour.\n2. Bake it.\n3. Cool it.")
    }

    @MainActor
    func testReturnInIngredientsStaysAPlainLineBreak() throws {
        let app = launchApp(photoText: ["ingredients": "2 cups flour"])
        openNewRecipe(app)
        fill(app, "Ingredients")
        app.staticTexts["2 cups flour"].tap()
        let editor = cardEditor(app, "ingredients")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        waitForKeyboard(app)
        tapEnd(of: editor)
        editor.typeText("\nsalt")
        XCTAssertEqual(editor.value as? String, "2 cups flour\nsalt")
    }

    @MainActor
    func testTheTopBarHasNoTitleText() throws {
        let app = launchApp()
        openNewRecipe(app)
        XCTAssertEqual(app.navigationBars.staticTexts.count, 0, "just the back button")
        typeTitle(app, "Soup")
        XCTAssertEqual(app.navigationBars.staticTexts.count, 0)
        XCTAssertEqual(titleField(app).value as? String, "Soup", "the large title is the recipe title")
    }

    @MainActor
    func testTappingAStepPutsTheCursorAtTheEndOfThatStep() throws {
        guard #available(iOS 18, *) else { return }  // the cursor can only be placed from iOS 18
        let app = launchApp(photoText: ["steps": "1. Mix the flour.\n2. Bake it.\n3. Cool it."])
        openNewRecipe(app)
        fill(app, "Steps")
        app.staticTexts["Bake it."].tap()
        let editor = cardEditor(app, "steps")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        waitForKeyboard(app)
        sleep(1)
        editor.typeText("!")
        XCTAssertEqual(editor.value as? String, "1. Mix the flour.\n2. Bake it.!\n3. Cool it.")
    }

    @MainActor
    func testEditingAStepNearTheTopOfALongListKeepsItOnScreen() throws {
        let many = (1...30).map { "\($0). Step number \($0) of the recipe." }.joined(separator: "\n")
        let app = launchApp(photoText: ["steps": many])
        openNewRecipe(app)
        fill(app, "Steps")
        // Scroll to the top, tap the first step, and type: the card must not jump to its bottom.
        app.swipeDown(velocity: .fast)
        let first = app.staticTexts["Step number 1 of the recipe."]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        let editor = cardEditor(app, "steps")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        waitForKeyboard(app)
        sleep(1)
        editor.typeText("x")
        sleep(1)
        XCTAssertGreaterThanOrEqual(editor.frame.minY, 0, "the top of the card, where the cursor is, stays on screen")
    }

    @MainActor
    func testEditingACardShowsPlaceholderButtonsAboveTheKeyboardAndBesideTheBackButton() throws {
        let app = launchApp(photoText: ["notes": "Rest the dough overnight."])
        openNewRecipe(app)
        fill(app, "Notes")
        for id in ["undoButton", "moreButton", "checkButton", "boldButton", "italicButton",
                   "underlineButton", "highlightButton", "linkButton", "listButton"] {
            XCTAssertFalse(app.buttons[id].exists, "\(id) is only there while editing")
        }

        app.staticTexts["noteText"].tap()
        XCTAssertTrue(cardEditor(app, "notes").waitForExistence(timeout: 5))
        waitForKeyboard(app)
        XCTAssertFalse(app.buttons["undoButton"].exists, "nothing to undo yet")
        XCTAssertFalse(app.buttons["shareButton"].exists)
        XCTAssertFalse(app.buttons["strikethroughButton"].exists)
        for id in ["moreButton", "checkButton", "boldButton", "italicButton",
                   "underlineButton", "highlightButton", "linkButton", "listButton"] {
            XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 5), id)
        }
        // The first group sits in the top bar, the second just above the keyboard.
        XCTAssertLessThan(app.buttons["checkButton"].frame.maxY, app.keyboards.firstMatch.frame.minY / 3)
        XCTAssertLessThanOrEqual(app.buttons["boldButton"].frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
        snap(app, "13-editing-buttons")
    }

    @MainActor
    func testUndoShowsAfterTypingAndTheCheckSavesTheCard() throws {
        let app = launchApp(photoText: ["notes": "Rest the dough."])
        openNewRecipe(app)
        fill(app, "Notes")
        app.staticTexts["noteText"].tap()
        let editor = cardEditor(app, "notes")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        waitForKeyboard(app)
        XCTAssertFalse(app.buttons["undoButton"].exists)

        editor.typeText(" Chill well.")
        XCTAssertTrue(app.buttons["undoButton"].waitForExistence(timeout: 5))
        // Each tap undoes a stretch of typing; the button leaves when nothing is left to undo.
        var taps = 0
        while app.buttons["undoButton"].waitForExistence(timeout: 1), taps < 40 {
            let undo = app.buttons["undoButton"]
            if undo.isHittable { undo.tap() }
            taps += 1
        }
        XCTAssertFalse(app.buttons["undoButton"].exists, "everything is undone")
        XCTAssertFalse((editor.value as? String ?? "").contains("Chill"), "the typed text is gone")

        editor.typeText(" Bake.")
        XCTAssertTrue(app.buttons["checkButton"].waitForExistence(timeout: 5))
        app.buttons["checkButton"].tap()
        XCTAssertTrue(app.staticTexts["noteText"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["noteText"].label.contains("Bake."), "the check saved the card")
        XCTAssertFalse(app.buttons["checkButton"].exists)
    }

    @MainActor
    func testTappingOutsideTheCardsSavesTheCardBeingEdited() throws {
        let app = launchApp(photoText: ["notes": "Rest the dough.", "ingredients": "2 eggs"])
        openNewRecipe(app)
        fill(app, "Notes")
        fill(app, "Ingredients")

        // On the heading of the card being edited.
        app.staticTexts["noteText"].tap()
        let editor = cardEditor(app, "notes")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        waitForKeyboard(app)
        editor.typeText(" Bake.")
        app.staticTexts["Notes"].firstMatch.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["noteText"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["noteText"].label.contains("Bake."))

        // Beside the title.
        app.staticTexts["noteText"].tap()
        XCTAssertTrue(cardEditor(app, "notes").waitForExistence(timeout: 5))
        waitForKeyboard(app)
        // Left of the title's field, in the page margin.
        let title = titleField(app)
        app.coordinate(withNormalizedOffset: CGVector(dx: 8 / app.frame.width, dy: title.frame.midY / app.frame.height)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertFalse(cardEditor(app, "notes").exists)
    }

    @MainActor
    func testStepsAddedAgainContinueTheNumbers() throws {
        let app = launchApp(photoText: ["steps": "1. Mix the flour.\n2. Bake it.\n3. Cool it."])
        openNewRecipe(app)
        fill(app, "Steps")
        // The same photo again: the same three steps, numbered 4, 5 and 6.
        fill(app, "Steps")

        for number in ["1", "2", "3", "4", "5", "6"] {
            XCTAssertTrue(app.staticTexts[number].exists, "step \(number)")
        }
        XCTAssertFalse(app.staticTexts["7"].exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: "stepTitle").count, 0)
        app.buttons["backButton"].tap()
        XCTAssertTrue(app.buttons["recipeRow"].firstMatch.label.contains("0 ingredients · 6 steps"))
    }

    // MARK: Filling and editing the cards in place

    @MainActor
    func testStepsTypedWithoutNumbersAreCheckedBeforeTheyAreSaved() throws {
        let app = launchApp(photoText: [
            "ingredients": "2 cups flour\n1 cup water\n3 eggs",
            "steps": "1. Mix the flour and water.\n2. Bake for 20 minutes.",
        ])
        openNewRecipe(app)
        fill(app, "Ingredients")
        addSection(app, "Steps")
        let editor = cardEditor(app, "steps")
        waitForKeyboard(app)

        // Typed text with no numbered line is not steps, and the card says so.
        editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 80))
        editor.typeText("Mix it")
        let message = app.staticTexts["sectionEditorMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue(message.label.contains("Only numbered steps are valid"))

        editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
        editor.typeText("1. Mix the flour and water.")
        editor.typeText("\n")  // Return numbers step 2
        sleep(1)
        editor.typeText("Bake for 20 minutes.")
        XCTAssertTrue(message.waitForNonExistence(timeout: 5), "the warning goes once the steps are numbered")
        snap(app, "7-typing-steps-in-the-card")
        tapDone(app)

        XCTAssertTrue(app.staticTexts["Mix the flour and water."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bake for 20 minutes."].exists)
        XCTAssertTrue(app.buttons["addSectionButton"].exists, "the plus stays, to add more")
        XCTAssertTrue(app.staticTexts["3 eggs"].exists, "the ingredients are untouched")

        app.buttons["backButton"].tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("3 ingredients · 2 steps"))
    }

    @MainActor
    func testTappingTheStepsEditsThemInPlaceAndOnlyTheStepsAreSaved() throws {
        let app = launchWithRecipe(steps: "1. Mix the flour and water.\n2. Bake for 20 minutes.")
        XCTAssertTrue(app.staticTexts["Mix the flour and water."].waitForExistence(timeout: 5))
        app.staticTexts["Mix the flour and water."].tap()

        let editor = cardEditor(app, "steps")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        let current = editor.value as? String ?? ""
        XCTAssertTrue(current.contains("1. Mix the flour and water"))
        XCTAssertTrue(current.contains("2. Bake for 20 minutes"))

        // Add a step, with a line under it that belongs to it.
        tapEnd(of: editor)
        editor.typeText("\n")  // Return starts step 3 by itself
        sleep(1)  // the cursor is placed a moment after the line break
        editor.typeText("Cool on a rack.")
        XCTAssertFalse(app.staticTexts["sectionEditorMessage"].exists, "no message under valid steps")
        snap(app, "8-editing-steps-in-place")
        tapDone(app)

        XCTAssertTrue(app.staticTexts["Cool on a rack."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Mix the flour and water."].exists)
        XCTAssertFalse(app.staticTexts["Ingredients"].exists, "only the steps were saved")
    }

    @MainActor
    func testIngredientsFromAPhotoNeedNoHeading() throws {
        let app = launchApp(photoText: [
            "ingredients": "salt\n2 cups flour",
            "steps": "1. Mix the flour and water.\n2. Bake for 20 minutes.",
        ])
        openNewRecipe(app)
        fill(app, "Steps")
        // No "Ingredients" heading is needed in the text, and a line with no amount counts.
        addSection(app, "Ingredients")
        // Ingredients are saved as written: no count, no check.
        XCTAssertFalse(app.staticTexts["sectionEditorMessage"].exists)
        tapDone(app)

        XCTAssertTrue(app.staticTexts["2 cups flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["salt"].exists)
        XCTAssertTrue(app.staticTexts["Bake for 20 minutes."].exists, "the steps are untouched")
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

        XCTAssertTrue(app.staticTexts["Ingredients"].waitForNonExistence(timeout: 5), "an emptied section goes away")
        XCTAssertTrue(app.buttons["addSectionButton"].exists)
        app.buttons["backButton"].tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Pancakes"))
        XCTAssertTrue(row.label.contains("0 ingredients · 0 steps"))
    }

    @MainActor
    func testTextWithNothingValidIsNotSaved() throws {
        let app = launchWithRecipe(steps: "1. Mix the flour and water.\n2. Bake for 20 minutes.")
        XCTAssertTrue(app.staticTexts["Mix the flour and water."].waitForExistence(timeout: 5))
        app.staticTexts["Mix the flour and water."].tap()

        let editor = cardEditor(app, "steps")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        waitForKeyboard(app)
        tapEnd(of: editor)
        // "1. Mix the flour and water." + "2. Bake for 20 minutes." and a line break: 51 characters.
        editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 51))
        editor.typeText("Mix it")
        tapDone(app)

        // It stays on screen with its message instead of replacing the steps.
        XCTAssertTrue(cardEditor(app, "steps").exists)
        XCTAssertTrue(app.staticTexts["sectionEditorMessage"].label.contains("Only numbered steps are valid"))

        // Leaving the screen drops it, and the saved steps are as they were.
        app.buttons["backButton"].tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("0 ingredients · 2 steps"))
        row.tap()
        XCTAssertTrue(app.staticTexts["Mix the flour and water."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bake for 20 minutes."].exists)
    }

    @MainActor
    func testTappingAnotherCardSavesTheOneBeingEdited() throws {
        let app = launchApp(photoText: [
            "ingredients": "2 cups flour\n1 cup water\n3 eggs",
            "steps": "1. Mix the flour and water.\n2. Bake for 20 minutes.",
        ])
        openNewRecipe(app)
        fill(app, "Ingredients")
        addSection(app, "Steps")
        XCTAssertTrue(cardEditor(app, "steps").exists)

        // No closing the keyboard: tap the ingredients card straight away.
        app.staticTexts["2 cups flour"].tap()
        XCTAssertTrue(cardEditor(app, "ingredients").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Mix the flour and water."].waitForExistence(timeout: 5), "the steps were saved")
        XCTAssertFalse(cardEditor(app, "steps").exists)
    }

    @MainActor
    func testNotesFromAPhotoAreEditedInPlace() throws {
        let app = launchApp(photoText: ["notes": "Rest the dough overnight."])
        openNewRecipe(app)
        fill(app, "Notes")

        // The note is kept as written.
        let card = app.staticTexts["noteText"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertEqual(card.label, "Rest the dough overnight.")

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

        app.buttons["backButton"].tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Garlic Toast"))
    }

    @MainActor
    func testAnEmptyTitleShowsTheTitleHintAndCanBeNamedAndClearedAgain() throws {
        let app = launchWithRecipe(ingredients: "2 cups flour\n1 cup water", steps: "1. Mix.\n2. Bake.")
        let title = titleField(app)
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Add Title", "the faded hint")
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
        XCTAssertEqual(title.value as? String, "Add Title")
        app.buttons["backButton"].tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Untitled recipe"))
    }

    // MARK: Search

    @MainActor
    func testSearchListsNamesUntilTypedThenFiltersTheCards() throws {
        let app = launchApp()
        for name in ["Soup", "Bread"] {
            openNewRecipe(app)
            typeTitle(app, name)
            app.buttons["backButton"].tap()
            XCTAssertTrue(app.buttons["searchButton"].waitForExistence(timeout: 5))
        }
        XCTAssertEqual(app.buttons.matching(identifier: "recipeRow").count, 2)
        XCTAssertFalse(app.textFields["searchField"].exists, "the field is hidden until the icon is tapped")

        // Open and empty: just the names, with no plus card.
        app.buttons["searchButton"].tap()
        let field = app.textFields["searchField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        waitForKeyboard(app)
        XCTAssertEqual(app.buttons.matching(identifier: "recipeRow").count, 2, "no input filters nothing")
        XCTAssertFalse(app.buttons["addRecipeButton"].exists, "a list of names has no plus card")

        // Typing filters the thumbnail cards.
        field.typeText("sou")
        XCTAssertEqual(app.buttons.matching(identifier: "recipeRow").count, 1)
        XCTAssertTrue(app.buttons["recipeRow"].firstMatch.label.contains("Soup"))
        XCTAssertTrue(app.buttons["addRecipeButton"].exists, "cards again, with the plus card")
        snap(app, "5-search")

        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3))
        XCTAssertEqual(app.buttons.matching(identifier: "recipeRow").count, 2)
        XCTAssertFalse(app.buttons["addRecipeButton"].exists, "back to the list of names")

        field.typeText("zzz")
        XCTAssertEqual(app.buttons.matching(identifier: "recipeRow").count, 0)

        // Closing the field clears the search.
        app.buttons["searchButton"].tap()
        XCTAssertFalse(field.exists)
        XCTAssertEqual(app.buttons.matching(identifier: "recipeRow").count, 2)
        XCTAssertTrue(app.buttons["addRecipeButton"].exists)
    }

    // MARK: The source link

    @MainActor
    func testSourceLinkCanBeAddedEditedAndRemoved() throws {
        let app = launchWithRecipe(
            ingredients: "2 slices bread\n1 tbsp butter",
            steps: "1. Toast the bread.\n2. Spread the butter."
        )
        snap(app, "12-no-source-link")

        // No link yet, so no Source link section and no pencil; it is added from the plus.
        XCTAssertFalse(app.staticTexts["Source link"].exists)
        XCTAssertFalse(app.buttons["editSourceLinkButton"].exists)
        app.buttons["addSectionButton"].tap()
        app.buttons["Source link"].tap()

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

        // Saved: the section shows the link and a pencil.
        let link = app.descendants(matching: .any)["sourceLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        XCTAssertTrue(link.label.contains("youtube.com/watch?v=abc"))
        XCTAssertTrue(app.staticTexts["Source link"].exists)
        snap(app, "14-source-link-saved")

        // Edit shows the saved link, and Remove takes it away again.
        app.buttons["editSourceLinkButton"].tap()
        let editField = app.textFields["sourceLinkField"]
        XCTAssertTrue(editField.waitForExistence(timeout: 5))
        XCTAssertTrue((editField.value as? String ?? "").contains("youtube.com/watch?v=abc"))
        app.buttons["removeSourceLinkButton"].tap()
        XCTAssertTrue(app.staticTexts["Source link"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["sourceLink"].exists)
    }

    // MARK: The list

    @MainActor
    func testHoldingACardOffersDelete() throws {
        let app = launchWithRecipe(
            title: "Toast",
            ingredients: "2 slices bread\n1 tbsp butter",
            steps: "1. Toast the bread.\n2. Spread the butter."
        )
        XCTAssertTrue(app.staticTexts["2 slices bread"].waitForExistence(timeout: 5))

        app.buttons["backButton"].tap()
        let row = app.buttons["recipeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        row.press(forDuration: 1)
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["recipeRow"].waitForNonExistence(timeout: 5), "the card is gone")
        XCTAssertTrue(app.buttons["addRecipeButton"].exists)
    }

    @MainActor
    func testHoldingACardOffersEditThumbnailInsideTheCard() throws {
        let app = launchApp()
        addCard(app)
        let row = app.buttons["recipeRow"].firstMatch
        row.press(forDuration: 1)

        let edit = app.buttons["editThumbnailButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertTrue(row.frame.contains(edit.frame), "the menu is inside the thumbnail")
        XCTAssertTrue(row.frame.contains(app.buttons["deleteRecipeButton"].frame))
        edit.tap()

        XCTAssertTrue(app.staticTexts["Edit thumbnail"].waitForExistence(timeout: 5), "the picture choices are for the thumbnail")
        app.buttons["Choose from library"].tap()
        XCTAssertTrue(app.buttons["usePhotoButton"].waitForExistence(timeout: 5), "cropped first")
        app.buttons["usePhotoButton"].tap()
        XCTAssertTrue(app.buttons["recipeRow"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "recipeRow").count, 1, "it changed the card, not added one")
        XCTAssertFalse(app.buttons["editThumbnailButton"].exists, "the menu closed")
    }

    @MainActor
    func testAFullHomeScreenScrollsToThePlusCard() throws {
        let app = launchApp()
        for _ in 0..<7 { addCard(app) }
        XCTAssertTrue(app.staticTexts["My Recipes"].isHittable)

        let plus = app.buttons["addRecipeButton"]
        var swipes = 0
        while !plus.isHittable, swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(plus.isHittable, "the plus card is at the end of the cards")
        XCTAssertTrue(app.staticTexts["My Recipes"].isHittable, "the title stays in place")
    }

    @MainActor
    func testPasteTextOpensAnEmptySectionAboveThePhotoChoices() throws {
        let app = launchApp()
        openNewRecipe(app)
        app.buttons["addSectionButton"].tap()
        app.buttons["Notes"].tap()

        let paste = app.buttons["Paste text"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Choose from library"].exists)
        XCTAssertFalse(app.staticTexts["Add a photo"].exists, "no title above the choices")
        XCTAssertLessThan(paste.frame.minY, app.buttons["Choose from library"].frame.minY, "it is the first choice")
        sleep(1)  // let the choices finish sliding in
        paste.tap()

        let editor = cardEditor(app, "notes")
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "an empty section to paste into")
        waitForKeyboard(app)
        XCTAssertEqual((editor.value as? String) ?? "", "")
        editor.typeText("Pasted note")
        app.buttons["checkButton"].tap()
        XCTAssertTrue(app.staticTexts["noteText"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testScanTextInTheMoreMenuReadsAPhotoIntoTheCardBeingEdited() throws {
        let app = launchApp(photoText: ["notes": "Rest the dough."])
        openNewRecipe(app)
        fill(app, "Notes")
        app.staticTexts["noteText"].tap()
        let editor = cardEditor(app, "notes")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        waitForKeyboard(app)
        // The Simulator has no camera, so scanning reads a library picture.
        app.buttons["moreButton"].tap()
        XCTAssertTrue(app.buttons["Scan text"].waitForExistence(timeout: 5))
        app.buttons["Scan text"].tap()
        let added = NSPredicate { _, _ in (self.cardEditor(app, "notes").value as? String)?.contains("Rest the dough.\nRest the dough.") == true }
        let expectation = XCTNSPredicateExpectation(predicate: added, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 10), .completed, "the photo's text was added after the note")
    }

    @MainActor
    func testTheLinkButtonAboveTheKeyboardOpensTheSourceLinkScreen() throws {
        let app = launchApp(photoText: ["notes": "Rest the dough."])
        openNewRecipe(app)
        fill(app, "Notes")
        app.staticTexts["noteText"].tap()
        XCTAssertTrue(cardEditor(app, "notes").waitForExistence(timeout: 5))
        waitForKeyboard(app)

        app.buttons["linkButton"].tap()
        XCTAssertTrue(app.textFields["sourceLinkField"].waitForExistence(timeout: 5), "the add source link screen")
        XCTAssertTrue(app.buttons["saveSourceLinkButton"].exists)
    }

    @MainActor
    func testSwipingANameInTheSearchListLeftShowsDelete() throws {
        let app = launchApp()
        for name in ["Soup", "Bread"] {
            openNewRecipe(app)
            typeTitle(app, name)
            app.buttons["backButton"].tap()
            XCTAssertTrue(app.buttons["searchButton"].waitForExistence(timeout: 5))
        }
        app.buttons["searchButton"].tap()
        XCTAssertTrue(app.textFields["searchField"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "recipeRow").count, 2)

        let soup = app.buttons.matching(identifier: "recipeRow").matching(NSPredicate(format: "label CONTAINS 'Soup'")).firstMatch
        XCTAssertTrue(soup.waitForExistence(timeout: 5))
        soup.swipeLeft()
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "swiping left shows Delete")
        delete.tap()

        XCTAssertTrue(soup.waitForNonExistence(timeout: 5), "the recipe is gone")
        XCTAssertEqual(app.buttons.matching(identifier: "recipeRow").count, 1)
        XCTAssertTrue(app.buttons.matching(identifier: "recipeRow").firstMatch.label.contains("Bread"))
    }

    @MainActor
    func testTappingElsewhereClosesTheCardMenuWithoutDoingAnything() throws {
        let app = launchApp()
        addCard(app)
        let row = app.buttons["recipeRow"].firstMatch

        // On the page below the card.
        row.press(forDuration: 1)
        XCTAssertTrue(app.buttons["editThumbnailButton"].waitForExistence(timeout: 5))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()
        XCTAssertTrue(app.buttons["editThumbnailButton"].waitForNonExistence(timeout: 5), "closed by a tap below")
        XCTAssertEqual(app.buttons.matching(identifier: "recipeRow").count, 1, "nothing was deleted")
        XCTAssertFalse(app.staticTexts["Add a thumbnail"].exists)

        // On the title.
        row.press(forDuration: 1)
        XCTAssertTrue(app.buttons["editThumbnailButton"].waitForExistence(timeout: 5))
        app.staticTexts["My Recipes"].tap()
        XCTAssertTrue(app.buttons["editThumbnailButton"].waitForNonExistence(timeout: 5), "closed by a tap on the title")

        // On the card itself: it only closes the menu, and the recipe does not open.
        row.press(forDuration: 1)
        XCTAssertTrue(app.buttons["editThumbnailButton"].waitForExistence(timeout: 5))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        XCTAssertTrue(app.buttons["editThumbnailButton"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["My Recipes"].exists, "still on the home screen")
    }

    @MainActor
    func testDeleteSectionInTheMoreMenuRemovesTheWholeSection() throws {
        let app = launchApp(photoText: ["notes": "Rest the dough.", "ingredients": "2 eggs"])
        openNewRecipe(app)
        fill(app, "Notes")
        fill(app, "Ingredients")
        app.staticTexts["noteText"].tap()
        XCTAssertTrue(cardEditor(app, "notes").waitForExistence(timeout: 5))
        waitForKeyboard(app)

        app.buttons["moreButton"].tap()
        XCTAssertTrue(app.buttons["Delete section"].waitForExistence(timeout: 5))
        app.buttons["Delete section"].tap()

        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Notes"].exists, "the Notes section is gone")
        XCTAssertFalse(app.staticTexts["noteText"].exists)
        XCTAssertTrue(app.staticTexts["2 eggs"].exists, "the other section stays")
        XCTAssertTrue(app.buttons["addSectionButton"].exists)
    }

    @MainActor
    func testTheDotsMenuClosesWithATapElsewhereAndHasEvenSides() throws {
        let app = launchApp(photoText: ["notes": "Rest the dough."])
        openNewRecipe(app)
        fill(app, "Notes")
        app.staticTexts["noteText"].tap()
        XCTAssertTrue(cardEditor(app, "notes").waitForExistence(timeout: 5))
        waitForKeyboard(app)

        app.buttons["moreButton"].tap()
        let delete = app.buttons["Delete section"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        snap(app, "14-dots-menu")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.45)).tap()
        XCTAssertTrue(delete.waitForNonExistence(timeout: 5), "a tap elsewhere closes the menu")
        XCTAssertTrue(cardEditor(app, "notes").exists, "and the card is still being edited")
    }
}
