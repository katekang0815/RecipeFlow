//
//  RecipeDetailView.swift
//  RecipeFlow
//

import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    @Bindable var recipe: Recipe

    private var isEmpty: Bool {
        recipe.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            RecipeTextField(text: $recipe.rawText, identifier: "recipeTextEditor")

            // The parser will hook in here; for now Create does nothing.
            Button {
            } label: {
                Text("Create").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isEmpty)
        }
        .padding(16)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }
}

#Preview {
    let container = PersistenceController.previewContainer(withSample: false)
    let recipe = Recipe()
    container.mainContext.insert(recipe)
    return NavigationStack { RecipeDetailView(recipe: recipe) }
        .modelContainer(container)
}
