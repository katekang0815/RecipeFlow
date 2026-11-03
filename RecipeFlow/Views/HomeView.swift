//
//  HomeView.swift
//  RecipeFlow
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @State private var newRecipe: Recipe?

    var body: some View {
        NavigationStack {
            Button(action: addRecipe) {
                Label("Add", systemImage: "plus")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.orange)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("RecipeFlow")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $newRecipe) { recipe in
                RecipeDetailView(recipe: recipe)
            }
        }
    }

    // Placeholder until the paste screen exists: start from a blank recipe.
    private func addRecipe() {
        let recipe = Recipe()
        context.insert(recipe)
        newRecipe = recipe
    }
}

#Preview {
    HomeView()
        .modelContainer(PersistenceController.previewContainer(withSample: false))
}
