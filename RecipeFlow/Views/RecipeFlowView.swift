//
//  RecipeFlowView.swift
//  RecipeFlow
//

import SwiftUI
import SwiftData

/// A saved recipe. The title and the Ingredients, Steps and Notes cards are edited in place:
/// tap one and type, with no edit icon. An empty card has a photo icon for adding by photo.
/// The source link has its own add and edit buttons.
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

    init(recipe: Recipe) {
        self.recipe = recipe
        _titleDraft = State(initialValue: recipe.title)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    titleField

                    editableSection(.ingredients, "Ingredients", hasContent: !recipe.ingredients.isEmpty) {
                        ingredients(recipe.sortedIngredients)
                    }
                    editableSection(.steps, "Steps", hasContent: !recipe.steps.isEmpty) {
                        steps(recipe.sortedSteps)
                    }
                    editableSection(.notes, "Notes", hasContent: !recipe.note.isEmpty) {
                        notes(recipe.note)
                    }

                    plainSection("Source link") { sourceLink }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: draft) {
                // Keep the bottom of the card being typed in, and its status line, above the keyboard.
                if let editing { proxy.scrollTo(editorID(editing), anchor: .bottom) }
            }
            .onChange(of: editing) { _, new in
                if let new { withAnimation { proxy.scrollTo(editorID(new), anchor: .center) } }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }
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
        .photoTextSource(isChoosing: $choosingPhoto, onOutcome: handlePhoto)
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
    /// An empty title shows "Untitled recipe" faded, as a hint that it can be typed over.
    private var titleField: some View {
        TextField(
            "",
            text: $titleDraft,
            prompt: Text(Recipe.untitledTitle).foregroundStyle(Theme.ink.opacity(0.45)),
            axis: .vertical
        )
        .font(.system(size: 30, weight: .bold))
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

    /// A card that is edited by tapping it. While it is empty its heading has a photo icon.
    private func editableSection<Content: View>(
        _ section: RecipeSection,
        _ title: String,
        hasContent: Bool,
        @ViewBuilder display: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                heading(title)
                Spacer()
                if !hasContent { photoButton(for: section) }
            }

            if editing == section {
                editor(for: section)
            } else {
                display()
                    .contentShape(Rectangle())
                    .onTapGesture { beginEditing(section) }
            }

            if let photoProblem, photoProblem.section == section {
                Text(photoProblem.text)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.7))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(title.lowercased() + "Section")
    }

    private func photoButton(for section: RecipeSection) -> some View {
        Button {
            photoTarget = section
            choosingPhoto = true
        } label: {
            PhotoAddIcon()
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.ink))
        }
        .accessibilityLabel("Add \(section.noun) from a photo")
        .accessibilityIdentifier("add\(section.noun.capitalized)PhotoButton")
    }

    /// The card while it is being edited: its text as a field, and what saving it would do.
    private func editor(for section: RecipeSection) -> some View {
        let parsed = SectionText.parse(section, draft)

        return VStack(alignment: .leading, spacing: 8) {
            TextField(
                "",
                text: $draft,
                prompt: Text(section.typingHint).foregroundStyle(Theme.ink.opacity(0.45)),
                axis: .vertical
            )
            .lineLimit(1...)
            .foregroundStyle(Theme.ink)
            .tint(Theme.ink)
            .focused($focus, equals: .section(section))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
            .accessibilityIdentifier("\(section.noun)Editor")

            if let status = SectionText.status(section, text: draft, parsed: parsed) {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.7))
                    .accessibilityIdentifier("sectionEditorMessage")
            }
        }
        .id(editorID(section))
    }

    private func editorID(_ section: RecipeSection) -> String { "editor-\(section.rawValue)" }

    private func placeholder(_ text: String, hint: String) -> some View {
        VStack(spacing: 6) {
            Text(text)
            Text(hint).font(.footnote)
        }
        .foregroundStyle(Theme.ink.opacity(0.45))
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
    }

    // MARK: Editing in place

    private func currentText(of section: RecipeSection) -> String {
        switch section {
        case .ingredients: recipe.ingredientsText
        case .steps: recipe.stepsText
        case .notes: recipe.note
        }
    }

    private func beginEditing(_ section: RecipeSection) {
        if editing != section {
            finishEditing(discardInvalid: true)
            editing = section
            draft = currentText(of: section)
            draftStart = draft
        }
        photoProblem = nil
        requestFocus(section)
    }

    private func requestFocus(_ section: RecipeSection) {
        focusRequest = section
        focus = .section(section)
    }

    /// Saves the card being edited. A blank card empties the section. Text with nothing valid in it,
    /// such as steps with no numbers, is not saved: it stays on screen with its message, or is dropped
    /// when `discardInvalid` is set.
    private func finishEditing(discardInvalid: Bool) {
        guard let section = editing else { return }

        let isBlank = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let parsed = SectionText.parse(section, draft)
        let found = SectionText.count(section, parsed)

        if isBlank {
            if draftStart != draft { apply(ParsedRecipe(), to: section) }
        } else if found > 0 {
            if draftStart != draft { apply(parsed, to: section) }
        } else if !discardInvalid {
            return
        }
        editing = nil
        draft = ""
        draftStart = ""
    }

    private func apply(_ parsed: ParsedRecipe, to section: RecipeSection) {
        switch section {
        case .ingredients: recipe.replaceIngredients(with: parsed.ingredients, in: context)
        case .steps: recipe.replaceSteps(with: parsed.steps, in: context)
        case .notes: recipe.note = parsed.note.joined(separator: "\n")
        }
    }

    /// A photo's text goes into the card for the user to check; it is saved like typed text.
    private func handlePhoto(_ outcome: PhotoText.Outcome) {
        guard let target = photoTarget else { return }
        switch outcome {
        case .text(let text):
            if editing == target {
                let current = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                draft = current.isEmpty ? text : current + "\n" + text
                focus = .section(target)
            } else {
                beginEditing(target)
                draft = text
            }
        case .problem(let message):
            photoProblem = (target, message)
        }
    }

    // MARK: Ingredients

    /// Consecutive ingredients with the same group, so each group gets one heading.
    private func grouped(_ items: [Ingredient]) -> [(group: String?, items: [Ingredient])] {
        var result: [(group: String?, items: [Ingredient])] = []
        for item in items {
            if let last = result.last, last.group == item.group {
                result[result.count - 1].items.append(item)
            } else {
                result.append((item.group, [item]))
            }
        }
        return result
    }

    @ViewBuilder
    private func ingredients(_ items: [Ingredient]) -> some View {
        if items.isEmpty {
            placeholder("No ingredients found", hint: "Tap to type, or tap the photo icon")
        } else {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(grouped(items).enumerated()), id: \.offset) { _, block in
                    VStack(alignment: .leading, spacing: 8) {
                        if let group = block.group {
                            Text(group)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        ForEach(block.items) { item in
                            ingredientRow(item)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
        }
    }

    /// "40 g bread flour", or "salt, to taste" when the amount has no number.
    private func label(for item: Ingredient) -> String {
        if item.quantity.contains(where: \.isNumber) || item.quantity.isEmpty {
            return [item.quantity, item.unit, item.name].filter { !$0.isEmpty }.joined(separator: " ")
        }
        return "\(item.name), \(item.quantity)"
    }

    private func ingredientRow(_ item: Ingredient) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label(for: item))
                .foregroundStyle(Theme.ink)
            if !item.prepNote.isEmpty {
                Text(item.prepNote)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.6))
            }
        }
    }

    // MARK: Steps

    @ViewBuilder
    private func steps(_ items: [Step]) -> some View {
        if items.isEmpty {
            placeholder("No steps found", hint: "Tap to type, or tap the photo icon")
        } else {
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
                            Text(step.title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            if !step.detail.isEmpty {
                                Text(step.detail)
                                    .foregroundStyle(Theme.ink.opacity(0.8))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
        }
    }

    // MARK: Notes

    @ViewBuilder
    private func notes(_ text: String) -> some View {
        if text.isEmpty {
            placeholder("No notes yet", hint: "Tap to type, or tap the photo icon")
        } else {
            Text(text)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
                .accessibilityIdentifier("noteText")
        }
    }

    // MARK: Source link

    /// One line like the ingredient card: the link on the left, + (add) or the pencil (edit) on the right.
    private var sourceLink: some View {
        let saved = recipe.sourceURL.flatMap(SourceLink.url(from:))

        return HStack(spacing: 12) {
            if let saved {
                Link(destination: saved) {
                    Text(saved.absoluteString)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .underline()
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("sourceLink")
            } else {
                Text("Add a source link")
                    .foregroundStyle(Theme.ink.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button { showLinkEditor = true } label: {
                Image(systemName: saved == nil ? "plus" : "pencil")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.ink))
            }
            .accessibilityLabel(saved == nil ? "Add source link" : "Edit source link")
            .accessibilityIdentifier(saved == nil ? "addSourceLinkButton" : "editSourceLinkButton")
        }
        .padding(.vertical, 10)
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
    }
}

#Preview {
    let container = PersistenceController.previewContainer(withSample: false)
    let recipe = Recipe.create(from: """
    Toast
    Ingredients
    2 slices bread
    1 tbsp butter
    salt to taste
    Directions
    1. Toast the bread. Let it cool a little.
    2. Spread the butter on top.
    """, in: container.mainContext)
    return NavigationStack { RecipeFlowView(recipe: recipe) }
        .modelContainer(container)
}
