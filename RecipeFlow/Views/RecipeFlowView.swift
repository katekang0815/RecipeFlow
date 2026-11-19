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
    @Environment(\.dismiss) private var dismiss

    /// What has the keyboard.
    private enum Field: Hashable {
        case title
    }
    @FocusState private var focus: Field?

    /// The title as it is being typed. It is saved to the recipe when editing ends.
    @State private var titleDraft: String

    /// The card being edited, its text, and the text it started with.
    @State private var editing: RecipeSection?
    @State private var draft = ""
    @State private var draftStart = ""
    /// How parts of the draft look (bold, colour, ...), and how they looked when editing began.
    @State private var draftRuns: [FormatRun] = []
    @State private var draftRunsStart: [FormatRun] = []
    /// The card being edited has the keyboard.
    @State private var sectionFocused = false
    @StateObject private var richText = RichTextController()

    /// The card a photo is being added to, and a problem reading it.
    @State private var photoTarget: RecipeSection?
    @State private var choosingPhoto = false
    @State private var photoProblem: (section: RecipeSection, text: String)?

    @State private var showLinkEditor = false
    /// The next change of the draft was made here, not typed.
    @State private var ignoreNextDraftChange = false
    /// Earlier states of the card being edited, newest last, for the undo button.
    private struct UndoStep { var text: String; var runs: [FormatRun] }
    @State private var undoStack: [UndoStep] = []
    @State private var lastUndoRecord = Date.distantPast
    /// A photo of steps with no numbered step in it.
    @State private var showOnlyNumbered = false

    init(recipe: Recipe) {
        self.recipe = recipe
        _titleDraft = State(initialValue: recipe.title)
    }

    var body: some View {
        VStack(spacing: 0) {
            // The title stays where it is while the sections scroll below it. It is 16 points higher than the
            // page used to have it, clear of the buttons above, with the sections where they were.
            titleField
                .padding(.horizontal, 16)
                .padding(.top, 36)
                .padding(.bottom, 12)
                // Tapping beside the title, outside every section, saves the card being edited.
                .background(Color.clear.contentShape(Rectangle()).onTapGesture { closeKeyboard() })
            sectionsScroll
        }
        .background(Theme.background.ignoresSafeArea())
        // The top bar is drawn here, above the page, so the title can sit up beside it without a bar over it.
        .overlay(alignment: .top) { topBar }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .background(SwipeBackEnabler())
        .onChange(of: focus) { old, new in
            if old == .title, new != .title { saveTitle() }
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
        .photoTextSource(isChoosing: $choosingPhoto, onPaste: pastePlainText) { outcome in
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

    /// Back on the left; while a card is edited, undo (once something was typed or pasted), more and save on the right.
    private var topBar: some View {
        HStack(spacing: 6) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color(red: 0.98, green: 0.97, blue: 0.73)))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .accessibilityIdentifier("backButton")

            Spacer()

            if editing != nil {
                if !undoStack.isEmpty { UndoButton(action: undo) }
                MoreButton()
                SaveButton { closeKeyboard() }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private var sectionsScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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
                            .allowsHitTesting(false)
                    }
                }
                // At least a page tall, so the empty part of a short page can be tapped to close the keyboard.
                .frame(minHeight: UIScreen.main.bounds.height * 0.8, alignment: .top)
                .background(Color.clear.contentShape(Rectangle()).onTapGesture { closeKeyboard() })
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            // A short page still drags, so dragging down closes the keyboard.
            .scrollBounceBehavior(.always, axes: .vertical)
            .onChange(of: draft) { _, _ in
                DispatchQueue.main.async { keepCursorInView(proxy) }
            }
            .onChange(of: editing) { _, new in
                // The cursor starts where it was put, at the end of the text unless a row was tapped.
                if new != nil { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { keepCursorInView(proxy) } }
            }
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
        // Room above and below the letters, so Korean letters with tails are not cut off at the bottom.
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 52)
        .foregroundStyle(Theme.ink)
        .tint(Theme.ink)
        .submitLabel(.done)
        .focused($focus, equals: .title)
        .contentShape(Rectangle())
        .onTapGesture {
            // The room around the letters, and an empty field beside its hint, take taps too.
            focus = .title
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

    /// Closes whatever has the keyboard. A card being edited is saved as its keyboard goes.
    private func closeKeyboard() {
        focus = nil
        sectionFocused = false
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
            // A tap on a heading goes to the page behind it, which saves the card being edited.
            .allowsHitTesting(false)
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
        // Opening the menu counts as a tap outside the card being edited.
        .simultaneousGesture(TapGesture().onEnded { closeKeyboard() })
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
            RichTextEditor(
                identifier: "\(section.noun)Editor",
                text: draft,
                runs: draftRuns,
                isFocused: sectionFocused,
                controller: richText,
                onEdit: { text, runs in editorChanged(text, runs) },
                onFocus: { focused in
                    sectionFocused = focused
                    // The keyboard left the card being edited, so save it.
                    if !focused, editing == section { finishEditing(discardInvalid: false) }
                }
            )
            .overlay(alignment: .topLeading) {
                if draft.isEmpty {
                    Text(section.typingHint)
                        .foregroundStyle(Theme.ink.opacity(0.45))
                        .padding(16)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
            .onChange(of: draft) { old, new in
                if section == .steps { startNextStepOnReturn(old: old, new: new) }
            }

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

    /// Scrolls so the line being edited is on screen, instead of always the bottom of the card. The cursor's
    /// place in the card is put at the same place in the window, so the card's top stays on screen for a line
    /// near the top, and its bottom for a line near the bottom.
    private func keepCursorInView(_ proxy: ScrollViewProxy) {
        guard let section = editing else { return }
        let fraction = richText.caretFraction() ?? 1
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
        // The look of the letters stays with them; the cursor goes in front of the new step's text.
        draftRuns = TextFormat.map(draftRuns, from: new, to: result.text)
        draft = result.text
        richText.requestSelection(String(result.text.prefix(result.caret)).utf16.count)
    }

    // MARK: Changing the text

    /// The text or its look was changed by typing or by a button. Typing in quick succession is one undo step.
    private func editorChanged(_ text: String, _ runs: [FormatRun]) {
        guard text != draft || runs != draftRuns else { return }
        recordUndoStep(text: draft, runs: draftRuns, becoming: text)
        draft = text
        draftRuns = runs
    }

    /// Changes the text from here, as a photo does. The look of the letters that stay is kept.
    private func replaceDraft(with text: String, caretAtEnd: Bool = false) {
        recordUndoStep(text: draft, runs: draftRuns, becoming: text)
        draftRuns = TextFormat.map(draftRuns, from: draft, to: text)
        draft = text
        if caretAtEnd { richText.requestSelection(text.utf16.count) }
    }

    // MARK: Undo

    private func recordUndoStep(text: String, runs: [FormatRun], becoming new: String) {
        guard editing != nil else { return }
        let typingOn = text != new && Date().timeIntervalSince(lastUndoRecord) < 1 && abs(new.count - text.count) <= 1
        lastUndoRecord = Date()
        if typingOn, !undoStack.isEmpty { return }
        undoStack.append(UndoStep(text: text, runs: runs))
    }

    private func undo() {
        guard let step = undoStack.popLast() else { return }
        // Only the steps card looks at line breaks, and only when the text changes.
        ignoreNextDraftChange = editing == .steps && step.text != draft
        draft = step.text
        draftRuns = step.runs
        lastUndoRecord = .distantPast
    }

    // MARK: Editing in place

    private func currentText(of section: RecipeSection) -> String {
        switch section {
        case .ingredients: recipe.ingredientsText
        case .steps: recipe.stepsText
        case .notes: recipe.note
        }
    }

    /// Starts editing a card. With a `line`, the cursor goes to the end of that line of the card's text;
    /// otherwise it is at the end of the text.
    private func beginEditing(_ section: RecipeSection, line: Int? = nil) {
        if editing != section {
            finishEditing(discardInvalid: true)
            editing = section
            draft = currentText(of: section)
            draftStart = draft
            draftRuns = recipe.formatRuns(for: section, matching: draft)
            draftRunsStart = draftRuns
            undoStack = []
            let lines = draft.components(separatedBy: "\n")
            if let line {
                let end = lines.prefix(min(line, lines.count - 1) + 1).reduce(0) { $0 + $1.utf16.count + 1 } - 1
                richText.requestSelection(max(0, min(end, draft.utf16.count)))
            } else {
                richText.requestSelection(draft.utf16.count)
            }
        }
        photoProblem = nil
        requestFocus(section)
    }

    private func requestFocus(_ section: RecipeSection) {
        focus = nil
        sectionFocused = true
    }

    /// Saves the card being edited. A blank card empties the section. Ingredients and notes are saved
    /// as written. Steps need a number: text with none is not saved, and stays on screen with its message,
    /// or is dropped when `discardInvalid` is set.
    private func finishEditing(discardInvalid: Bool) {
        guard let section = editing else { return }

        let isBlank = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let changed = draftStart != draft
        let restyled = draftRunsStart != draftRuns

        if isBlank {
            if changed { apply(draft, to: section) }
            recipe.setFormat([], text: "", for: section)
        } else if section == .steps, StepParser.parse(draft).isEmpty {
            if !discardInvalid { return }
        } else if changed || restyled {
            if changed { apply(draft, to: section) }
            // The saved text can differ a little from the typed text (numbers, spaces), so the look is carried over.
            let saved = currentText(of: section)
            recipe.setFormat(TextFormat.map(draftRuns, from: draft, to: saved), text: saved, for: section)
        }
        editing = nil
        sectionFocused = false
        draft = ""
        draftStart = ""
        draftRuns = []
        draftRunsStart = []
        undoStack = []
    }

    private func apply(_ text: String, to section: RecipeSection) {
        switch section {
        case .ingredients: recipe.replaceIngredients(withLines: SectionText.lines(text), in: context)
        case .steps: recipe.replaceSteps(with: StepParser.parse(text), in: context)
        case .notes: recipe.note = SectionText.lines(text).joined(separator: "\n")
        }
    }

    /// "Paste text": the section opens empty with the keyboard, for the user to paste or type into.
    private func pastePlainText() {
        guard let target = photoTarget else { return }
        beginEditing(target)
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
            replaceDraft(
                with: target == .steps ? SectionText.appendingSteps(text, to: draft) : SectionText.appending(text, to: draft),
                caretAtEnd: true
            )
        case .problem(let message):
            photoProblem = (target, message)
        }
    }

    // MARK: Formatted text

    /// One line of a saved card, with its bold, slanted, underlined and coloured letters. `prefix` is what the
    /// card's text has in front of the line's own text (a step's number). A card that was changed after it was
    /// formatted shows plain.
    private func formattedText(_ section: RecipeSection, line: Int, prefix: String = "", plain: String) -> Text {
        // A blank line still takes up a line's height.
        guard !plain.isEmpty else { return Text(" ") }
        let full = currentText(of: section)
        let runs = recipe.formatRuns(for: section, matching: full)
        guard !runs.isEmpty else { return Text(plain) }
        let lines = full.components(separatedBy: "\n")
        guard line < lines.count else { return Text(plain) }
        let start = lines.prefix(line).reduce(0) { $0 + $1.utf16.count + 1 } + prefix.utf16.count
        let range = NSRange(location: start, length: plain.utf16.count)
        let styles = TextFormat.styles(from: runs, count: full.utf16.count)
        return Text(TextFormat.attributed(full, styles: styles, in: range))
    }

    // MARK: Ingredients

    @ViewBuilder
    private func ingredients(_ items: [Ingredient]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                formattedText(.ingredients, line: index, plain: Recipe.line(for: item))
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
                        formattedText(.steps, line: index, prefix: "\(index + 1). ", plain: step.title)
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
        formattedText(.notes, line: 0, plain: text)
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
}

/// The undo button, with no plate behind it, shown beside the back button once something was typed or pasted.
private struct UndoButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                // The whole 44-point square takes the tap, not just the lines of the arrow.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Undo")
        .accessibilityIdentifier("undoButton")
    }
}

/// The three dots, with no plate behind them. Placeholder for now.
private struct MoreButton: View {
    var body: some View {
        Button {} label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More")
        .accessibilityIdentifier("moreButton")
    }
}

/// The yellow check: saves the card, the same as tapping outside it.
private struct SaveButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(EditingStyle.gold))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Save")
        .accessibilityIdentifier("checkButton")
    }
}

/// Keeps the swipe from the left edge going back, which the system turns off when its own top bar is hidden.
private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { Controller() }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    private final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.delegate = nil
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}
