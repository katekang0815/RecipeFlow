//
//  RecipeFlowView.swift
//  RecipeFlow
//

import SwiftUI
import SwiftData

/// A saved recipe: its ingredients and steps. Plain lists for now;
/// icons and editing come later.
struct RecipeFlowView: View {
    var recipe: Recipe

    @Environment(\.modelContext) private var context
    /// The title as it is being typed. It is saved to the recipe when editing ends.
    @State private var titleDraft: String
    @FocusState private var titleFocused: Bool

    init(recipe: Recipe) {
        self.recipe = recipe
        _titleDraft = State(initialValue: recipe.title)
    }
    @State private var showLinkEditor = false
    @State private var editing: RecipeSection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                titleField

                section("Ingredients", edit: .ingredients, hasContent: !recipe.ingredients.isEmpty) {
                    ingredients(recipe.sortedIngredients)
                }
                section("Steps", edit: .steps, hasContent: !recipe.steps.isEmpty) {
                    steps(recipe.sortedSteps)
                }
                section("Notes", edit: .notes, hasContent: !recipe.note.isEmpty) {
                    notes(recipe.note)
                }
                section("Source link") { sourceLink }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .sheet(item: $editing) { target in
            SectionEditor(
                section: target,
                initialText: currentText(of: target),
                isEditing: hasContent(target)
            ) { parsed in
                switch target {
                case .steps: recipe.replaceSteps(with: parsed.steps, in: context)
                case .ingredients: recipe.replaceIngredients(with: parsed.ingredients, in: context)
                case .notes: recipe.note = parsed.note.joined(separator: "\n")
                }
            }
        }
        .sheet(isPresented: $showLinkEditor) {
            SourceLinkEditor(
                current: recipe.sourceURL,
                onSave: { recipe.sourceURL = $0 },
                onRemove: { recipe.sourceURL = nil }
            )
        }
    }

    /// A section with its heading. A section the user can fill in has a round button on the heading:
    /// + while it is empty, a pencil once it has content. Both open the same add or edit screen.
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
        .focused($titleFocused)
        .contentShape(Rectangle())
        .onTapGesture {
            // An empty field only reacts to taps on its hint text; make the whole row work.
            if titleDraft.isEmpty { titleFocused = true }
        }
        .accessibilityIdentifier("recipeTitle")
        .onChange(of: titleDraft) { _, new in
            // A long title wraps, so Return ends editing instead of adding a line.
            if new.contains("\n") {
                titleDraft = new.replacingOccurrences(of: "\n", with: "")
                titleFocused = false
            }
        }
        .onChange(of: titleFocused) { _, focused in
            if !focused { saveTitle() }
        }
        .onDisappear { saveTitle() }
    }

    private func saveTitle() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        titleDraft = trimmed
        if recipe.title != trimmed { recipe.title = trimmed }
    }

    private func section<Content: View>(
        _ title: String,
        edit: RecipeSection? = nil,
        hasContent: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if let edit {
                    Button { editing = edit } label: {
                        Image(systemName: hasContent ? "pencil" : "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Theme.ink))
                    }
                    .accessibilityLabel("\(hasContent ? "Edit" : "Add") \(edit.noun)")
                    .accessibilityIdentifier("\(hasContent ? "edit" : "add")\(edit.noun.capitalized)Button")
                }
            }
            content()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(title.lowercased() + "Section")
    }

    private func placeholder(_ text: String, hint: String) -> some View {
        VStack(spacing: 6) {
            Text(text)
            Text(hint).font(.footnote)
        }
        .foregroundStyle(Theme.ink.opacity(0.45))
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
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
            placeholder("No ingredients found", hint: "Tap + to add ingredients")
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
            placeholder("No steps found", hint: "Tap + to add steps")
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
            placeholder("No notes yet", hint: "Tap + to add notes")
        } else {
            Text(text)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
                .accessibilityIdentifier("noteText")
        }
    }

    // MARK: Editing

    /// The section's current content as text, for the edit screen.
    private func currentText(of section: RecipeSection) -> String {
        switch section {
        case .ingredients: recipe.ingredientsText
        case .steps: recipe.stepsText
        case .notes: recipe.note
        }
    }

    private func hasContent(_ section: RecipeSection) -> Bool {
        switch section {
        case .ingredients: !recipe.ingredients.isEmpty
        case .steps: !recipe.steps.isEmpty
        case .notes: !recipe.note.isEmpty
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
