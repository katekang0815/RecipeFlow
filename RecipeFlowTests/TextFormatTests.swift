//
//  TextFormatTests.swift
//  RecipeFlowTests
//

import Testing
import Foundation
import SwiftData
import UIKit
@testable import RecipeFlow

@MainActor
struct TextFormatTests {
    private let bold = CharStyle(bold: true)

    @Test func runsAndStylesRoundTrip() {
        let runs = [
            FormatRun(location: 2, length: 3, style: bold),
            FormatRun(location: 7, length: 2, style: CharStyle(italic: true, color: .mint)),
        ]
        let styles = TextFormat.styles(from: runs, count: 10)
        #expect(styles.count == 10)
        #expect(styles[1].isPlain && styles[2] == bold && styles[4] == bold && styles[5].isPlain)
        #expect(TextFormat.runs(from: styles) == runs)
    }

    @Test func lettersKeepTheirLookWhenTextIsAddedBefore() {
        let runs = [FormatRun(location: 2, length: 3, style: bold)]
        let mapped = TextFormat.map(runs, from: "a b cde", to: "xx a b cde")
        #expect(mapped == [FormatRun(location: 5, length: 3, style: bold)])
    }

    @Test func lettersKeepTheirLookWhenTextIsRemovedBefore() {
        let runs = [FormatRun(location: 5, length: 3, style: bold)]
        #expect(TextFormat.map(runs, from: "xx a bcd", to: "a bcd") == [FormatRun(location: 2, length: 3, style: bold)])
    }

    @Test func newLettersAreNotStyled() {
        let runs = [FormatRun(location: 0, length: 3, style: bold)]
        let mapped = TextFormat.map(runs, from: "abc", to: "abcdef")
        #expect(mapped == runs)
    }

    @Test func renumberedStepsKeepTheLookOfTheirText() {
        // The step text "Bake" is bold; renumbering 9. to 10. moves it along.
        let old = "9. Bake"
        let runs = [FormatRun(location: 3, length: 4, style: bold)]
        let mapped = TextFormat.map(runs, from: old, to: "10. Bake")
        #expect(mapped == [FormatRun(location: 4, length: 4, style: bold)])
    }

    @Test func shownTextHasTheSameLettersWithTheLook() {
        let text = "Mix well"
        let styles = TextFormat.styles(from: [FormatRun(location: 4, length: 4, style: bold)], count: 8)
        let shown = TextFormat.attributed(text, styles: styles, in: NSRange(location: 0, length: 8))
        #expect(String(shown.characters) == "Mix well")
        let part = TextFormat.attributed(text, styles: styles, in: NSRange(location: 4, length: 4))
        #expect(String(part.characters) == "well")
    }

    @Test func koreanTextKeepsItsLook() {
        let text = "안녕 하세요"
        let styles = TextFormat.styles(from: [FormatRun(location: 3, length: 3, style: bold)], count: text.utf16.count)
        #expect(String(TextFormat.attributed(text, styles: styles, in: NSRange(location: 3, length: 3)).characters) == "하세요")
    }

    @Test func textViewStylesRoundTrip() {
        let styles = [bold, bold, .plain, CharStyle(underline: true, color: .blue), .plain]
        let shown = TextViewStyle.attributed("abcde", styles: styles)
        #expect(shown.string == "abcde")
        #expect(TextViewStyle.styles(of: shown) == styles)
    }

    @Test func formattingOnlyAppliesToTheTextItWasMadeFor() throws {
        let context = ModelContext(PersistenceController.previewContainer(withSample: false))
        let recipe = Recipe(title: "Bread")
        context.insert(recipe)
        recipe.note = "Rest overnight"
        let runs = [FormatRun(location: 0, length: 4, style: bold)]
        recipe.setFormat(runs, text: "Rest overnight", for: .notes)

        #expect(recipe.formatRuns(for: .notes, matching: "Rest overnight") == runs)
        #expect(recipe.formatRuns(for: .notes, matching: "Rest a day").isEmpty)
        #expect(recipe.formatRuns(for: .steps, matching: "Rest overnight").isEmpty)

        recipe.setFormat([], text: "Rest overnight", for: .notes)
        #expect(recipe.formatting == nil)
    }

    // MARK: The buttons

    private func editor(_ text: String, selecting range: NSRange) -> (UITextView, RichTextController) {
        let view = UITextView()
        view.attributedText = TextViewStyle.attributed(text, styles: [])
        view.selectedRange = range
        let controller = RichTextController()
        controller.textView = view
        return (view, controller)
    }

    @Test func boldMakesTheSelectedLettersBoldAndAgainTakesItOff() {
        let (view, controller) = editor("Mix the flour", selecting: NSRange(location: 4, length: 3))
        controller.toggle(\.bold)
        let styles = TextViewStyle.styles(of: view.attributedText)
        #expect(styles[3].isPlain && styles[4].bold && styles[6].bold && styles[7].isPlain)
        #expect(view.text == "Mix the flour")
        #expect(view.selectedRange == NSRange(location: 4, length: 3))
        #expect(controller.style.bold)

        controller.toggle(\.bold)
        #expect(TextViewStyle.styles(of: view.attributedText).allSatisfy { $0.isPlain })
    }

    @Test func italicAndUnderlineAddToWhatIsThere() {
        let (view, controller) = editor("Mix the flour", selecting: NSRange(location: 0, length: 3))
        controller.toggle(\.bold)
        controller.toggle(\.italic)
        controller.toggle(\.underline)
        #expect(TextViewStyle.styles(of: view.attributedText)[1] == CharStyle(bold: true, italic: true, underline: true))
    }

    @Test func partlyBoldSelectionBecomesAllBold() {
        let (view, controller) = editor("abcdef", selecting: NSRange(location: 0, length: 2))
        controller.toggle(\.bold)
        view.selectedRange = NSRange(location: 0, length: 4)
        controller.toggle(\.bold)
        #expect(TextViewStyle.styles(of: view.attributedText).prefix(4).allSatisfy { $0.bold })
    }

    @Test func colourColoursTheLettersAndNoneClearsIt() {
        let (view, controller) = editor("Mix the flour", selecting: NSRange(location: 0, length: 3))
        controller.setColor(.pink)
        #expect(TextViewStyle.styles(of: view.attributedText)[0].color == .pink)
        let attributes = view.attributedText.attributes(at: 0, effectiveRange: nil)
        #expect(attributes[.foregroundColor] as? UIColor == FormatColor.pink.ui)
        #expect(attributes[.backgroundColor] != nil)

        controller.setColor(nil)
        #expect(TextViewStyle.styles(of: view.attributedText).allSatisfy { $0.isPlain })
    }

    @Test func withNothingSelectedTheButtonStylesWhatIsTypedNext() {
        let (view, controller) = editor("Mix", selecting: NSRange(location: 3, length: 0))
        controller.toggle(\.bold)
        #expect(TextViewStyle.style(fromAttributes: view.typingAttributes).bold)
        #expect(controller.style.bold)
        #expect(TextViewStyle.styles(of: view.attributedText).allSatisfy { $0.isPlain })
    }

    // MARK: Lists

    @Test func aListMarkerIsFoundAtTheStartOfALine() {
        #expect(ListKind.marker(of: "• milk")?.kind == .bulleted)
        #expect(ListKind.marker(of: "- milk")?.kind == .dashed)
        #expect(ListKind.marker(of: "12. milk")?.number == 12)
        #expect(ListKind.marker(of: "12.5 g milk") == nil)
        #expect(ListKind.marker(of: "milk") == nil)
    }

    @Test func bulletedMakesTheCursorsLineAListLine() {
        let (view, controller) = editor("Milk\nEggs\nFlour", selecting: NSRange(location: 7, length: 0))
        controller.applyList(.bulleted)
        #expect(view.text == "Milk\n• Eggs\nFlour")
        #expect(view.selectedRange == NSRange(location: 9, length: 0))
        #expect(controller.list == .bulleted)
    }

    @Test func switchingListsReplacesTheMarkerAndNoneTakesItOff() {
        let (view, controller) = editor("• Milk", selecting: NSRange(location: 6, length: 0))
        controller.applyList(.dashed)
        #expect(view.text == "- Milk")
        controller.applyList(.numbered)
        #expect(view.text == "1. Milk")
        controller.applyList(nil)
        #expect(view.text == "Milk")
        #expect(view.selectedRange == NSRange(location: 4, length: 0))
    }

    @Test func numberedCountsOnFromTheLineAbove() {
        let (view, controller) = editor("1. Milk\n2. Eggs\nFlour", selecting: NSRange(location: 17, length: 0))
        controller.applyList(.numbered)
        #expect(view.text == "1. Milk\n2. Eggs\n3. Flour")
    }

    @Test func aSelectionOfLinesBecomesOneList() {
        let (view, controller) = editor("Milk\nEggs\nFlour", selecting: NSRange(location: 0, length: 10))
        controller.applyList(.numbered)
        #expect(view.text == "1. Milk\n2. Eggs\nFlour")
    }

    @Test func anEmptyLineGetsTheMarkerAndTheCursorGoesAfterIt() {
        let (view, controller) = editor("Milk\n", selecting: NSRange(location: 5, length: 0))
        controller.applyList(.bulleted)
        #expect(view.text == "Milk\n• ")
        #expect(view.selectedRange == NSRange(location: 7, length: 0))
    }

    @Test func listMarkersKeepTheFontOfTheText() {
        let (view, controller) = editor("Milk", selecting: NSRange(location: 0, length: 0))
        controller.applyList(.bulleted)
        let font = view.attributedText.attributes(at: 0, effectiveRange: nil)[.font] as? UIFont
        #expect(font?.pointSize == TextViewStyle.baseFont.pointSize)
    }
}
