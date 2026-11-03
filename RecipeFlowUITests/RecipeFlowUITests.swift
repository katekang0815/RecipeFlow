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

        app.buttons["Add"].tap()
        let editor = app.textViews["pasteTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))

        let create = app.buttons["Create recipe"]
        XCTAssertFalse(create.isEnabled, "Create should be disabled while the text is empty")

        editor.tap()
        editor.typeText("Toast\nIngredients: bread")
        XCTAssertTrue(create.isEnabled)
        create.tap()

        // The title field grows vertically, so it can surface as a text view or a text field.
        let title = app.descendants(matching: .any)["Recipe title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
