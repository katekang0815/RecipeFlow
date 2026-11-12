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

    @State private var showLinkEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(recipe.displayTitle)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("recipeTitle")

                section("Ingredients") { ingredients(recipe.sortedIngredients) }
                section("Steps") { steps(recipe.sortedSteps) }
                if !recipe.note.isEmpty {
                    section("Note") { note(recipe.note) }
                }
                section("Source link") { sourceLink }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .sheet(isPresented: $showLinkEditor) {
            SourceLinkEditor(
                current: recipe.sourceURL,
                onSave: { recipe.sourceURL = $0 },
                onRemove: { recipe.sourceURL = nil }
            )
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.ink)
            content()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(title.lowercased() + "Section")
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
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
            placeholder("No ingredients found")
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
            placeholder("No steps found")
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

    // MARK: Note

    private func note(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
            .accessibilityIdentifier("noteText")
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
