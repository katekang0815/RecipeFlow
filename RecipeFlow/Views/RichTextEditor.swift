//
//  RichTextEditor.swift
//  RecipeFlow
//

import Combine
import SwiftUI
import UIKit

/// The kinds of list the list button makes.
enum ListKind: String, CaseIterable, Identifiable {
    case bulleted, dashed, numbered

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .bulleted: "list.bullet"
        case .dashed: "list.dash"
        case .numbered: "list.number"
        }
    }

    /// What starts a line of this list; `number` is the line's place in a numbered list.
    func marker(number: Int) -> String {
        switch self {
        case .bulleted: "• "
        case .dashed: "- "
        case .numbered: "\(number). "
        }
    }

    /// The marker a line starts with, and its length in UTF-16 units. Nil for a line that is not in a list.
    static func marker(of line: String) -> (kind: ListKind, length: Int, number: Int?)? {
        guard let match = markerPattern.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) else { return nil }
        let text = (line as NSString).substring(with: match.range).trimmingCharacters(in: .whitespaces)
        let kind: ListKind = text == "•" ? .bulleted : (text.hasSuffix(".") ? .numbered : .dashed)
        return (kind, match.range.length, kind == .numbered ? Int(text.dropLast()) : nil)
    }

    private static let markerPattern = try! NSRegularExpression(pattern: "^(?:•|-|–|[0-9]+\\.)[ \\t]+")
}

/// Lets the buttons above the keyboard act on the text being edited.
final class RichTextController: ObservableObject {
    weak var textView: UITextView?
    /// Called after a button changed the look of the text.
    var changed: (() -> Void)?
    /// How the letters at the cursor, or at the start of the selection, look.
    @Published var style = CharStyle.plain
    /// The kind of list the cursor's line is in.
    @Published var list: ListKind?
    /// Where the cursor goes at the next update, in UTF-16 units.
    var pendingSelection: Int?
    /// The link button: opens the screen for the recipe's source link.
    var openLink: (() -> Void)?

    func requestSelection(_ location: Int) { pendingSelection = location }

    // MARK: Buttons

    func toggle(_ keyPath: WritableKeyPath<CharStyle, Bool>) {
        guard let textView else { return }
        let range = textView.selectedRange
        if range.length == 0 {
            var typing = typingStyle(textView)
            typing[keyPath: keyPath].toggle()
            setTyping(typing, in: textView)
            return
        }
        let styles = TextViewStyle.styles(of: textView.attributedText)
        let on = !styles[range.location..<(range.location + range.length)].allSatisfy { $0[keyPath: keyPath] }
        modify(range) { $0[keyPath: keyPath] = on }
    }

    func setColor(_ color: FormatColor?) {
        guard let textView else { return }
        let range = textView.selectedRange
        if range.length == 0 {
            var typing = typingStyle(textView)
            typing.color = color
            setTyping(typing, in: textView)
            return
        }
        modify(range) { $0.color = color }
    }

    // MARK: Reading

    func refreshStyle() {
        guard let textView else { return }
        let range = textView.selectedRange
        let found: CharStyle
        if range.length > 0, range.location < textView.attributedText.length {
            found = TextViewStyle.style(fromAttributes: textView.attributedText.attributes(at: range.location, effectiveRange: nil))
        } else {
            found = typingStyle(textView)
        }
        if found != style { style = found }
        let line = currentLine(in: textView)
        let kind = ListKind.marker(of: line.text)?.kind
        if kind != list { list = kind }
    }

    // MARK: Lists

    private func currentLine(in textView: UITextView) -> (text: String, start: Int) {
        let text = textView.text as NSString
        let location = min(textView.selectedRange.location, text.length)
        let range = text.lineRange(for: NSRange(location: location, length: 0))
        var line = text.substring(with: range)
        if line.hasSuffix("\n") { line.removeLast() }
        return (line, range.location)
    }

    /// Makes the line the cursor is on (or every line of the selection) a list line, or takes it out of its list.
    /// A numbered list counts on from the numbered line above.
    func applyList(_ kind: ListKind?) {
        guard let textView else { return }
        let text = textView.text as NSString
        let selection = textView.selectedRange
        let first = text.lineRange(for: NSRange(location: min(selection.location, text.length), length: 0))
        // A selection that ends just after a line break does not reach into the next line.
        var endPlace = min(selection.location + selection.length, text.length)
        if selection.length > 0, endPlace > 0, text.character(at: endPlace - 1) == 10 { endPlace -= 1 }
        let last = text.lineRange(for: NSRange(location: endPlace, length: 0))

        // Each line from the first to the last: where it starts, and the marker it has now.
        var lines: [(start: Int, old: Int, text: String)] = []
        var position = first.location
        repeat {
            let range = text.lineRange(for: NSRange(location: position, length: 0))
            var line = text.substring(with: range)
            if line.hasSuffix("\n") { line.removeLast() }
            lines.append((range.location, ListKind.marker(of: line)?.length ?? 0, line))
            position = NSMaxRange(range)
        } while position < NSMaxRange(last)

        // A numbered list goes on from the line above.
        var number = 1
        if first.location > 0 {
            let above = text.lineRange(for: NSRange(location: first.location - 1, length: 0))
            if let marker = ListKind.marker(of: text.substring(with: above).trimmingCharacters(in: .newlines)), let n = marker.number {
                number = n + 1
            }
        }
        var edits: [(start: Int, old: Int, marker: String)] = []
        for line in lines {
            // Empty lines in a selection of several lines stay empty.
            let isBlank = line.text.trimmingCharacters(in: .whitespaces).isEmpty
            if let kind, !(isBlank && lines.count > 1) {
                edits.append((line.start, line.old, kind.marker(number: number)))
                number += 1
            } else {
                edits.append((line.start, line.old, ""))
            }
        }

        let plain = TextViewStyle.attributes(for: .plain)
        let storage = textView.textStorage
        storage.beginEditing()
        for edit in edits.reversed() {
            storage.replaceCharacters(
                in: NSRange(location: edit.start, length: edit.old),
                with: NSAttributedString(string: edit.marker, attributes: plain)
            )
        }
        storage.endEditing()

        // The cursor and the selection move with the text. A cursor inside an old marker goes after the new one.
        func shifted(_ place: Int) -> Int {
            var offset = 0
            for edit in edits {
                let newLength = (edit.marker as NSString).length
                if place < edit.start { break }
                if place < edit.start + edit.old { return edit.start + offset + newLength }
                offset += newLength - edit.old
            }
            return place + offset
        }
        let start = shifted(selection.location)
        let stop = shifted(selection.location + selection.length)
        let length = (textView.text as NSString).length
        textView.selectedRange = NSRange(location: min(start, length), length: max(0, min(stop, length) - min(start, length)))
        refreshStyle()
        changed?()
    }

    /// Where the cursor is in the editor, from its top (0) to its bottom (1).
    func caretFraction() -> CGFloat? {
        guard let textView, let range = textView.selectedTextRange else { return nil }
        textView.layoutIfNeeded()
        guard textView.bounds.height > 0 else { return nil }
        let rect = textView.caretRect(for: range.end)
        guard rect.midY.isFinite else { return nil }
        return min(max(rect.midY / textView.bounds.height, 0), 1)
    }

    // MARK: Changing the text

    private func typingStyle(_ textView: UITextView) -> CharStyle {
        TextViewStyle.style(fromAttributes: textView.typingAttributes)
    }

    private func setTyping(_ typing: CharStyle, in textView: UITextView) {
        textView.typingAttributes = TextViewStyle.attributes(for: typing)
        style = typing
    }

    private func modify(_ range: NSRange, _ change: (inout CharStyle) -> Void) {
        guard let textView else { return }
        var styles = TextViewStyle.styles(of: textView.attributedText)
        for index in range.location..<min(range.location + range.length, styles.count) { change(&styles[index]) }
        textView.attributedText = TextViewStyle.attributed(textView.text, styles: styles)
        textView.selectedRange = range
        refreshStyle()
        changed?()
    }
}

/// A text view for a card, where parts of the text can be bold, slanted, underlined or coloured.
/// It grows with its text, so the page scrolls instead of the editor.
struct RichTextEditor: UIViewRepresentable {
    let identifier: String
    let text: String
    let runs: [FormatRun]
    let isFocused: Bool
    let controller: RichTextController
    /// Typed or formatted: the text and its runs now.
    let onEdit: (String, [FormatRun]) -> Void
    /// The keyboard came or went.
    let onFocus: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        view.textContainer.lineFragmentPadding = 0
        view.tintColor = TextViewStyle.baseColor
        view.adjustsFontForContentSizeCategory = true
        view.typingAttributes = TextViewStyle.attributes(for: .plain)
        view.accessibilityIdentifier = identifier
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.inputAccessoryView = context.coordinator.makeAccessory(controller: controller)
        controller.textView = view
        controller.changed = { [weak coordinator = context.coordinator, weak view] in
            guard let coordinator, let view else { return }
            coordinator.push(view)
        }
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        controller.textView = view

        // Only when the text or its look differs from the state, so typing and composing are left alone.
        if view.markedTextRange == nil {
            let wanted = TextFormat.styles(from: runs, count: text.utf16.count)
            if view.text != text || TextViewStyle.styles(of: view.attributedText) != wanted {
                let selection = view.selectedRange
                coordinator.updating = true
                view.attributedText = TextViewStyle.attributed(text, styles: wanted)
                let length = (text as NSString).length
                let location = min(selection.location, length)
                view.selectedRange = NSRange(location: location, length: min(selection.length, length - location))
                coordinator.updating = false
                DispatchQueue.main.async { controller.refreshStyle() }
            }
        }
        if let location = controller.pendingSelection {
            controller.pendingSelection = nil
            let length = (view.text as NSString).length
            view.selectedRange = NSRange(location: min(max(location, 0), length), length: 0)
            DispatchQueue.main.async { controller.refreshStyle() }
        }

        if isFocused, !view.isFirstResponder {
            DispatchQueue.main.async { if view.window != nil { view.becomeFirstResponder() } }
        } else if !isFocused, view.isFirstResponder {
            // Resigning tells the delegate, which changes state, so not while the view is being updated.
            DispatchQueue.main.async { view.resignFirstResponder() }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(size.height))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        var updating = false
        private var hosting: UIHostingController<EditingKeyboardButtons>?

        init(_ parent: RichTextEditor) { self.parent = parent }

        /// The buttons above the keyboard, with room around them so they float.
        func makeAccessory(controller: RichTextController) -> UIView {
            let host = UIHostingController(rootView: EditingKeyboardButtons(controller: controller))
            host.view.backgroundColor = .clear
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            let container = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 62))
            container.backgroundColor = .clear
            host.view.frame = container.bounds
            container.addSubview(host.view)
            hosting = host
            return container
        }

        func push(_ view: UITextView) {
            parent.onEdit(view.text ?? "", TextFormat.runs(from: TextViewStyle.styles(of: view.attributedText)))
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !updating else { return }
            push(textView)
            parent.controller.refreshStyle()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !updating else { return }
            parent.controller.refreshStyle()
        }

        func textViewDidBeginEditing(_ textView: UITextView) { parent.onFocus(true) }
        func textViewDidEndEditing(_ textView: UITextView) { parent.onFocus(false) }
    }
}

// MARK: - Buttons above the keyboard

private enum KeyboardBarStyle {
    static let bar = Color.white.opacity(0.9)
}

/// Bold, italic, underline, colour, link and list in a rounded bar that floats above the keyboard.
struct EditingKeyboardButtons: View {
    @ObservedObject var controller: RichTextController

    var body: some View {
        HStack {
            glyph(Text("B").font(.system(size: 22, weight: .bold)), id: "boldButton", label: "Bold") { controller.toggle(\.bold) }
            Spacer()
            glyph(Text("I").font(.system(size: 22).italic()), id: "italicButton", label: "Italic") { controller.toggle(\.italic) }
            Spacer()
            glyph(Text("U").font(.system(size: 22)).underline(), id: "underlineButton", label: "Underline") { controller.toggle(\.underline) }
            Spacer()
            colorMenu
            Spacer()
            symbol("link", id: "linkButton", label: "Source link") { controller.openLink?() }
            Spacer()
            listMenu
        }
        .padding(.horizontal, 20)
        .frame(height: 46)
        .background(Capsule().fill(KeyboardBarStyle.bar))
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private func glyph(_ text: Text, id: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            text
                .foregroundStyle(Color.black)
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    /// Bulleted, dashed or numbered list on the line the cursor is on; None takes the line out of its list.
    private var listMenu: some View {
        Menu {
            Button {
                controller.applyList(nil)
            } label: {
                if controller.list == nil { Label("None", systemImage: "checkmark") } else { Text("None") }
            }
            Divider()
            Picker("List", selection: Binding(
                get: { controller.list },
                set: { controller.applyList($0) }
            )) {
                ForEach(ListKind.allCases) { kind in
                    Label(kind.title, systemImage: kind.symbol).tag(Optional(kind))
                }
            }
        } label: {
            Image(systemName: "list.bullet")
                .font(.system(size: 20))
                .foregroundStyle(Theme.ink)
                .frame(width: 38, height: 38)
        }
        .accessibilityLabel("List")
        .accessibilityIdentifier("listButton")
    }

    private func symbol(_ name: String, id: String, label: String, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 20))
                .foregroundStyle(Theme.ink)
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    /// The highlighter: None, then a colour for the letters and the background behind them.
    private var colorMenu: some View {
        Menu {
            Button {
                controller.setColor(nil)
            } label: {
                if controller.style.color == nil { Label("None", systemImage: "checkmark") } else { Text("None") }
            }
            Divider()
            Picker("Colour", selection: Binding(
                get: { controller.style.color },
                set: { controller.setColor($0) }
            )) {
                ForEach(FormatColor.allCases) { color in
                    Label { Text(color.title) } icon: { Image(uiImage: Self.dot(color)) }
                        .tag(Optional(color))
                }
            }
        } label: {
            Image(systemName: "highlighter")
                .font(.system(size: 20))
                .foregroundStyle(controller.style.color?.color ?? Theme.ink)
                .frame(width: 38, height: 38)
        }
        .accessibilityLabel("Colour")
        .accessibilityIdentifier("highlightButton")
    }

    private static func dot(_ color: FormatColor) -> UIImage {
        let size = CGSize(width: 14, height: 14)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            color.ui.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
        }
        return image.withRenderingMode(.alwaysOriginal)
    }
}
