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

        XCTAssertTrue(app.staticTexts["Tangzhong Bread"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["Note"].exists, "note heading")
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
        XCTAssertTrue(app.staticTexts["Note"].exists)
        XCTAssertFalse(app.staticTexts["ignoredLines"].exists)
        snap(app, "11-bulleted-steps-and-note")
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
