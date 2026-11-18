//
//  RecipeFlowView.swift
//  RecipeFlow
//

import SwiftUI
import SwiftData

/// A recipe. A new recipe opens here with just a title and one plus button. The plus drops down
/// Ingredients, Steps, Notes and Source link; each is added from its own photo and then shows in its
/// place, above the plus. A card is edited in place by tapping it, with no edit icon.
struct RecipeFlowView: View {
    var recipe: Recipe

    @Environment(\.modelContext) private var context

    /// What has the keyboard.
    private enum Field: Hashable {
        case title
        case section(RecipeSection)
    }
    @FocusState private var focus: Field?

    /// The title as it is being typed. It is saved to the recipe when editing ends.
    @State private var titleDraft: String

    /// The card being edited, its text, and the text it started with.
    @State private var editing: RecipeSection?
    @State private var draft = ""
    @State private var draftStart = ""
    /// A card that is waiting for the keyboard, see `requestFocus`.
    @State private var focusRequest: RecipeSection?

    /// The card a photo is being added to, and a problem reading it.
    @State private var photoTarget: RecipeSection?
    @State private var choosingPhoto = false
    @State private var photoProblem: (section: RecipeSection, text: String)?

    @State private var showLinkEditor = false
    /// The cursor in the card being edited, where the system lets it be set (iOS 18); a `TextSelection`.
    @State private var selectionBox: Any?
    /// The next change of the draft was made here, not typed.
    @State private var ignoreNextDraftChange = false
    /// A photo of steps with no numbered step in it.
    @State private var showOnlyNumbered = false

    init(recipe: Recipe) {
        self.recipe = recipe
        _titleDraft = State(initialValue: recipe.title)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    titleField

                    // Only the sections that have something show, always in this order.
                    if shows(.ingredients) {
                        editableSection(.ingredients, "Ingredients") {
                            ingredients(recipe.sortedIngredients)
                        }
                    }
                    if shows(.steps) {
                        editableSection(.steps, "Steps") {
                            steps(recipe.sortedSteps)
                        }
                    }
                    if shows(.notes) {
                        editableSection(.notes, "Notes") {
                            notes(recipe.note)
                        }
                    }
                    if hasSourceLink {
                        plainSection("Source link") { sourceLink }
                    }

                    // The one add button stays below the last section.
                    addSectionMenu
                    if let photoProblem {
                        Text(photoProblem.text)
                            .font(.footnote)
                            .foregroundStyle(Theme.ink.opacity(0.7))
                    }
                }
                // At least a page tall, so the empty part of a short page can be tapped to close the keyboard.
                .frame(minHeight: UIScreen.main.bounds.height * 0.5, alignment: .top)
                .background(Color.clear.contentShape(Rectangle()).onTapGesture { focus = nil })
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            // A short page still drags, so dragging down closes the keyboard.
            .scrollBounceBehavior(.always, axes: .vertical)
            .onChange(of: draft) { old, new in
                keepCursorInView(proxy, old: old, new: new)
            }
            .onChange(of: editing) { _, new in
                // The cursor starts where it was put, at the end of the text unless a row was tapped.
                if new != nil { DispatchQueue.main.async { keepCursorInView(proxy, old: nil, new: draft) } }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        // No title in the top bar: the large title below is enough.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            // While a card is edited: buttons beside the back button and above the keyboard. They are
            // placeholders for now and do nothing yet.
            if editing != nil {
                ToolbarItem(placement: .topBarTrailing) { EditingTopButtons() }
                ToolbarItem(placement: .keyboard) { EditingKeyboardButtons() }
            }
        }
        .onChange(of: focus) { old, new in
            if old == .title, new != .title { saveTitle() }
            if let request = focusRequest {
                // A card is waiting for the keyboard. The card it replaced can hand focus to nobody
                // on its way off the screen, so ask again until it lands.
                if new == .section(request) { focusRequest = nil } else { focus = .section(request) }
                return
            }
            // The keyboard left the card being edited, so save it.
            if let editing, new != .section(editing) { finishEditing(discardInvalid: false) }
        }
        .onDisappear {
            saveTitle()
            finishEditing(discardInvalid: true)
        }
        // The alert is below the photo choices, not on the same view, so it can show as they go.
        .alert(SectionText.onlyNumberedSteps, isPresented: $showOnlyNumbered) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Start each step with a number, like 1. 2. 3.")
        }
        .photoTextSource(isChoosing: $choosingPhoto) { outcome in
            handlePhoto(fakeText(for: photoTarget) ?? outcome)
        }
        .sheet(isPresented: $showLinkEditor) {
            SourceLinkEditor(
                current: recipe.sourceURL,
                onSave: { recipe.sourceURL = $0 },
                onRemove: { recipe.sourceURL = nil }
            )
        }
    }

    // MARK: Title

    /// The title is the text field itself, so tapping it edits it and there is no edit icon.
    /// An empty title shows "Add Title" faded, as a hint that it can be typed over.
    private var titleField: some View {
        TextField(
            "",
            text: $titleDraft,
            prompt: Text("Add Title").foregroundStyle(Theme.ink.opacity(0.45)),
            axis: .vertical
        )
        .font(.system(size: 30, weight: .bold))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .foregroundStyle(Theme.ink)
        .tint(Theme.ink)
        .submitLabel(.done)
        .focused($focus, equals: .title)
        .contentShape(Rectangle())
        .onTapGesture {
            // An empty field only reacts to taps on its hint text; make the whole row work.
            if titleDraft.isEmpty { focus = .title }
        }
        .accessibilityIdentifier("recipeTitle")
        .onChange(of: titleDraft) { _, new in
            // A long title wraps, so Return ends editing instead of adding a line.
            if new.contains("\n") {
                titleDraft = new.replacingOccurrences(of: "\n", with: "")
                focus = nil
            }
        }
    }

    private func saveTitle() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        titleDraft = trimmed
        if recipe.title != trimmed { recipe.title = trimmed }
    }

    // MARK: Sections

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(Theme.ink)
    }

    /// A section with no buttons of its own.
    private func plainSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            heading(title)
            content()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(title.lowercased() + "Section")
    }

    /// A card that is edited by tapping it. Its heading has a plus for adding more by photo.
    private func editableSection<Content: View>(
        _ section: RecipeSection,
        _ title: String,
        @ViewBuilder display: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            heading(title)

            if editing == section {
                editor(for: section)
            } else {
                display()
                    .contentShape(Rectangle())
                    .onTapGesture { beginEditing(section) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(title.lowercased() + "Section")
    }

    private func shows(_ section: RecipeSection) -> Bool {
        if editing == section { return true }
        switch section {
        case .ingredients: return !recipe.ingredients.isEmpty
        case .steps: return !recipe.steps.isEmpty
        case .notes: return !recipe.note.isEmpty
        }
    }

    private var hasSourceLink: Bool {
        recipe.sourceURL.flatMap(SourceLink.url(from:)) != nil
    }

    /// The only add button: a plus that drops down the four sections. Choosing one asks for a photo
    /// (or, for the source link, opens its editor); the section then appears in its place above the plus.
    private var addSectionMenu: some View {
        Menu {
            ForEach([RecipeSection.ingredients, .steps, .notes], id: \.self) { section in
                Button(section.noun.capitalized) {
                    photoTarget = section
                    choosingPhoto = true
                }
            }
            Button("Source link") { showLinkEditor = true }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
        }
        .accessibilityLabel("Add a section")
        .accessibilityIdentifier("addSectionButton")
    }

    /// For UI tests: the text a photo of this section "contains", from the launch arguments.
    private func fakeText(for section: RecipeSection?) -> PhotoText.Outcome? {
        guard let section,
              let text = UserDefaults.standard.string(forKey: "fakePhotoText.\(section.noun)") else { return nil }
        // Launch arguments cannot carry line breaks, so a test writes them as ⏎.
        return .text(text.replacingOccurrences(of: "⏎", with: "\n"))
    }

    /// The card while it is being edited: its text as a field, and what saving it would do.
    private func editor(for section: RecipeSection) -> some View {
        return VStack(alignment: .leading, spacing: 8) {
            cardTextField(for: section)
            .lineLimit(1...)
            .onChange(of: draft) { old, new in
                if section == .steps { startNextStepOnReturn(old: old, new: new) }
            }
            .foregroundStyle(Theme.ink)
            .tint(Theme.ink)
            .focused($focus, equals: .section(section))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
            // The padding around the text takes the cursor too, instead of counting as empty page.
            .contentShape(Rectangle())
            .onTapGesture { focus = .section(section) }
            .accessibilityIdentifier("\(section.noun)Editor")

            // Only steps are checked: ingredients and notes are saved as written.
            if section == .steps, let status = SectionText.stepsStatus(draft) {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.7))
                    .accessibilityIdentifier("sectionEditorMessage")
            }
        }
        .id(editorID(section))
    }

    private func editorID(_ section: RecipeSection) -> String { "editor-\(section.rawValue)" }

    @ViewBuilder
    private func cardTextField(for section: RecipeSection) -> some View {
        let prompt = Text(section.typingHint).foregroundStyle(Theme.ink.opacity(0.45))
        if #available(iOS 18, *) {
            TextField("", text: $draft, selection: selectionBinding, prompt: prompt, axis: .vertical)
        } else {
            TextField("", text: $draft, prompt: prompt, axis: .vertical)
        }
    }

    @available(iOS 18, *)
    private var selectionBinding: Binding<TextSelection?> {
        Binding(get: { selectionBox as? TextSelection }, set: { selectionBox = $0 })
    }

    /// The cursor's place in `text`, in characters, where the system lets it be read (iOS 18).
    private func cursorOffset(in text: String) -> Int? {
        guard #available(iOS 18, *), let selection = selectionBox as? TextSelection,
              case .selection(let range) = selection.indices,
              range.lowerBound >= text.startIndex, range.lowerBound <= text.endIndex else { return nil }
        return text.distance(from: text.startIndex, to: range.lowerBound)
    }

    /// Scrolls so the line being edited is on screen, instead of always the bottom of the card. The line is
    /// found by counting line breaks before the cursor, and put where it is in the card, so the card's top
    /// stays on screen for a line near the top, and its bottom for a line near the bottom.
    /// Before iOS 18 the cursor cannot be read: the end of the text is followed while typing at the end,
    /// and typing in the middle is left to the system.
    private func keepCursorInView(_ proxy: ScrollViewProxy, old: String?, new: String) {
        guard let section = editing else { return }
        let fraction: CGFloat
        if let offset = cursorOffset(in: new) {
            let lines = new.components(separatedBy: "\n")
            let line = new.prefix(offset).filter { $0 == "\n" }.count
            fraction = (CGFloat(line) + 0.5) / CGFloat(max(lines.count, 1))
        } else if old == nil || old.map({ new.hasPrefix($0) || $0.hasPrefix(new) }) == true {
            fraction = 1
        } else {
            return
        }
        proxy.scrollTo(editorID(section), anchor: UnitPoint(x: 0.5, y: fraction))
    }

    /// Return in the steps starts the next step where the cursor is, and numbers the steps again.
    private func startNextStepOnReturn(old: String, new: String) {
        if ignoreNextDraftChange {
            ignoreNextDraftChange = false
            return
        }
        guard editing == .steps, let result = StepEditing.splitAtReturn(old: old, new: new), result.text != new else { return }
        ignoreNextDraftChange = true
        draft = result.text
        // Before iOS 18 the cursor cannot be placed, so it stays at the end of the text. The cursor is placed
        // a moment later: the text field sets its own cursor when the line break is typed, which would win.
        if #available(iOS 18, *) {
            let text = result.text, caret = result.caret
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                guard editing == .steps, draft == text else { return }
                selectionBox = TextSelection(insertionPoint: text.index(text.startIndex, offsetBy: min(caret, text.count)))
            }
        }
    }

    // MARK: Editing in place

    private func currentText(of section: RecipeSection) -> String {
        switch section {
        case .ingredients: recipe.ingredientsText
        case .steps: recipe.stepsText
        case .notes: recipe.note
        }
    }

    /// Starts editing a card. With a `line`, the cursor goes to the end of that line of the card's text (iOS 18);
    /// otherwise, and before iOS 18, it is at the end of the text.
    private func beginEditing(_ section: RecipeSection, line: Int? = nil) {
        if editing != section {
            finishEditing(discardInvalid: true)
            editing = section
            draft = currentText(of: section)
            draftStart = draft
            if #available(iOS 18, *), let line {
                let lines = draft.components(separatedBy: "\n")
                let end = lines.prefix(min(line, lines.count - 1) + 1).reduce(0) { $0 + $1.count + 1 } - 1
                selectionBox = TextSelection(insertionPoint: draft.index(draft.startIndex, offsetBy: max(0, min(end, draft.count))))
            } else if #available(iOS 18, *) {
                selectionBox = nil
            }
        }
        photoProblem = nil
        requestFocus(section)
    }

    private func requestFocus(_ section: RecipeSection) {
        focusRequest = section
        focus = .section(section)
    }

    /// Saves the card being edited. A blank card empties the section. Ingredients and notes are saved
    /// as written. Steps need a number: text with none is not saved, and stays on screen with its message,
    /// or is dropped when `discardInvalid` is set.
    private func finishEditing(discardInvalid: Bool) {
        guard let section = editing else { return }

        let isBlank = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let changed = draftStart != draft

        if isBlank {
            if changed { apply(draft, to: section) }
        } else if section == .steps, StepParser.parse(draft).isEmpty {
            if !discardInvalid { return }
        } else if changed {
            apply(draft, to: section)
        }
        editing = nil
        draft = ""
        draftStart = ""
    }

    private func apply(_ text: String, to section: RecipeSection) {
        switch section {
        case .ingredients: recipe.replaceIngredients(withLines: SectionText.lines(text), in: context)
        case .steps: recipe.replaceSteps(with: StepParser.parse(text), in: context)
        case .notes: recipe.note = SectionText.lines(text).joined(separator: "\n")
        }
    }

    /// A photo's text is added after what the card already holds, and shown for the user to check.
    /// It is saved like typed text.
    private func handlePhoto(_ outcome: PhotoText.Outcome) {
        guard let target = photoTarget else { return }
        switch outcome {
        case .text(let text):
            // Steps are only numbered ones: a photo with none is not added.
            if target == .steps, StepParser.parse(text).isEmpty {
                // A moment later, so the photo choices have gone and the alert can show.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    showOnlyNumbered = true
                }
                return
            }
            if editing != target {
                beginEditing(target)
            } else {
                requestFocus(target)
            }
            draft = target == .steps ? SectionText.appendingSteps(text, to: draft) : SectionText.appending(text, to: draft)
        case .problem(let message):
            photoProblem = (target, message)
        }
    }

    // MARK: Ingredients

    @ViewBuilder
    private func ingredients(_ items: [Ingredient]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Text(Recipe.line(for: item))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { beginEditing(.ingredients, line: index) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
    }

    // MARK: Steps

    @ViewBuilder
    private func steps(_ items: [Step]) -> some View {
        // One card for every step, like the ingredients card above it.
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.ink))

                    VStack(alignment: .leading, spacing: 4) {
                        // A step is one paragraph. Steps saved by an older version also have a detail line.
                        Text(step.title)
                            .foregroundStyle(Theme.ink)
                        if !step.detail.isEmpty {
                            Text(step.detail)
                                .foregroundStyle(Theme.ink)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
                .onTapGesture { beginEditing(.steps, line: index) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
    }

    // MARK: Notes

    @ViewBuilder
    private func notes(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
            .accessibilityIdentifier("noteText")
    }

    // MARK: Source link

    /// One line like the ingredient card: the link on the left and a pencil to change or remove it.
    private var sourceLink: some View {
        HStack(spacing: 12) {
            if let saved = recipe.sourceURL.flatMap(SourceLink.url(from:)) {
                Link(destination: saved) {
                    Text(saved.absoluteString)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .underline()
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("sourceLink")
            }

            Button { showLinkEditor = true } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.ink))
            }
            .accessibilityLabel("Edit source link")
            .accessibilityIdentifier("editSourceLinkButton")
        }
        .padding(.vertical, 10)
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
    }
}

#Preview {
    let container = PersistenceController.previewContainer(withSample: false)
    let recipe = Recipe(title: "Toast")
    container.mainContext.insert(recipe)
    recipe.replaceIngredients(withLines: ["2 slices bread", "1 tbsp butter"], in: container.mainContext)
    recipe.replaceSteps(with: StepParser.parse("1. Toast the bread. Let it cool a little.\n2. Spread the butter on top."), in: container.mainContext)
    return NavigationStack { RecipeFlowView(recipe: recipe) }
        .modelContainer(container)
}

// MARK: - Buttons shown while a card is edited (placeholders)

private enum EditingStyle {
    static let gold = Color(red: 0.89, green: 0.69, blue: 0.22)
    /// The white rounded bar behind a group of buttons.
    static let bar = Color.white.opacity(0.85)
}

/// Undo, share and more in one rounded bar, then a round check button, level with the back button.
private struct EditingTopButtons: View {
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 18) {
                button("arrow.uturn.backward", id: "undoButton", label: "Undo")
                button("square.and.arrow.up", id: "shareButton", label: "Share")
                button("ellipsis", id: "moreButton", label: "More")
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Capsule().fill(EditingStyle.bar))

            Button {} label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(EditingStyle.gold))
            }
            .accessibilityLabel("Done")
            .accessibilityIdentifier("checkButton")
        }
    }

    private func button(_ symbol: String, id: String, label: String) -> some View {
        Button {} label: {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Theme.ink)
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

/// Bold, italic, underline, strikethrough, highlight, link and list, evenly spaced above the keyboard.
private struct EditingKeyboardButtons: View {
    var body: some View {
        HStack {
            Button {} label: {
                Text("B")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(EditingStyle.gold))
            }
            .accessibilityLabel("Bold")
            .accessibilityIdentifier("boldButton")
            Spacer()
            glyph(Text("I").font(.system(size: 22, weight: .regular).italic()), id: "italicButton", label: "Italic")
            Spacer()
            glyph(Text("U").font(.system(size: 22)).underline(), id: "underlineButton", label: "Underline")
            Spacer()
            glyph(Text("S").font(.system(size: 22)).strikethrough(), id: "strikethroughButton", label: "Strikethrough")
            Spacer()
            symbol("highlighter", id: "highlightButton", label: "Highlight")
            Spacer()
            symbol("link", id: "linkButton", label: "Link")
            Spacer()
            symbol("list.bullet", id: "listButton", label: "List")
        }
        .frame(maxWidth: .infinity)
    }

    private func glyph(_ text: Text, id: String, label: String) -> some View {
        Button {} label: {
            text.foregroundStyle(Theme.ink).frame(width: 40, height: 40)
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private func symbol(_ name: String, id: String, label: String) -> some View {
        Button {} label: {
            Image(systemName: name)
                .font(.system(size: 20))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}
