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
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testAddButtonOpensPasteScreenAndCreatesRecipe() throws {
        let app = XCUIApplication()
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
        snap(app, "5-split-recipe")
    }

    @MainActor
    func testCreateTurnsAwayTextThatIsNotARecipe() throws {
        let app = XCUIApplication()
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
