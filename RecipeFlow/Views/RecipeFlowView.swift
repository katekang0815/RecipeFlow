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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(recipe.displayTitle)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("recipeTitle")

                section("Ingredients") { ingredients(recipe.sortedIngredients) }
                section("Steps") { steps(recipe.sortedSteps) }

                if !recipe.ignoredLines.isEmpty {
                    ignored(recipe.ignoredLines)
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
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
            VStack(spacing: 12) {
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
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
                }
            }
        }
    }

    // MARK: Ignored lines

    private func ignored(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(lines.count) line\(lines.count == 1 ? "" : "s") ignored")
                .font(.footnote.weight(.semibold))
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line).font(.footnote)
            }
        }
        .foregroundStyle(Theme.ink.opacity(0.6))
        .accessibilityIdentifier("ignoredLines")
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
