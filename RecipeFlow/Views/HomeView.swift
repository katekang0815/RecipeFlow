//
//  HomeView.swift
//  RecipeFlow
//

import SwiftUI
import SwiftData

struct HomeView: View {
    private enum Route: Hashable {
        case paste
        case recipe(Recipe)
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @State private var path: [Route] = []

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
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .paste:
                    PasteView(onCreate: createRecipe)
                case .recipe(let recipe):
                    RecipeFlowView(recipe: recipe)
                }
            }
        }
        .tint(Theme.ink)
    }

    private var addButton: some View {
        Button { path.append(.paste) } label: {
            Label("Add", systemImage: "plus")
        }
        .buttonStyle(PrimaryButtonStyle())
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
                    Button { path.append(.recipe(recipe)) } label: {
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

    // MARK: Creating

    // The recipe replaces the paste screen so Back returns home.
    private func createRecipe(from text: String) {
        let recipe = Recipe.create(from: text, in: context)
        path = [.recipe(recipe)]
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
