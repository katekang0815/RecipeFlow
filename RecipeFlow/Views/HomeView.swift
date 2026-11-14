//
//  HomeView.swift
//  RecipeFlow
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @State private var path: [Recipe] = []
    /// The recipe that Add just made. If the user comes back without putting anything in it,
    /// it is not kept.
    @State private var newRecipe: Recipe?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if recipes.isEmpty {
                    addButton
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    recipeList
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Recipe.self) { recipe in
                // The recipe screen saves what was typed before it says it was left,
                // so this is the time to check whether anything was.
                RecipeFlowView(recipe: recipe, onLeave: dropNewRecipeIfBlank)
            }
        }
        .tint(Theme.ink)
    }

    /// Add opens an empty recipe straight away; each section is filled in on that screen.
    private var addButton: some View {
        Button(action: addRecipe) {
            Label("Add", systemImage: "plus")
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private func addRecipe() {
        let recipe = Recipe()
        context.insert(recipe)
        newRecipe = recipe
        path.append(recipe)
    }

    /// Only once the recipe screen is really gone: it also reports leaving while the camera covers it.
    private func dropNewRecipeIfBlank() {
        guard let recipe = newRecipe, !path.contains(where: { $0 === recipe }) else { return }
        newRecipe = nil
        if recipe.isBlank { recipe.delete(from: context) }
    }

    // MARK: Saved recipes

    private var recipeList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("My recipes")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            List {
                ForEach(recipes) { recipe in
                    Button { path.append(recipe) } label: {
                        RecipeRow(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recipeRow")
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                .onDelete(perform: deleteRecipes)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("recipeList")
        }
        .safeAreaInset(edge: .bottom) {
            addButton
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.background)
        }
    }

    private func deleteRecipes(at offsets: IndexSet) {
        for index in offsets { recipes[index].delete(from: context) }
    }
}

private struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.displayTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.6))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ink.opacity(0.4))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
        .contentShape(Rectangle())
    }

    private var summary: String {
        let ingredients = recipe.ingredients.count
        let steps = recipe.steps.count
        let date = recipe.createdAt.formatted(date: .abbreviated, time: .omitted)
        return "\(ingredients) ingredient\(ingredients == 1 ? "" : "s") · \(steps) step\(steps == 1 ? "" : "s") · \(date)"
    }
}

#Preview("Empty") {
    HomeView()
        .modelContainer(PersistenceController.previewContainer(withSample: false))
}

#Preview("With recipes") {
    HomeView()
        .modelContainer(PersistenceController.previewContainer(withSample: true))
}
