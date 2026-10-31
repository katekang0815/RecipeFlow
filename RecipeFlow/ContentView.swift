//
//  ContentView.swift
//  RecipeFlow
//
//  Created by Kate Kang on 10/24/26.
//

import SwiftUI
import SwiftData

/// Temporary root: shows the first saved recipe. The home list and paste screen replace this.
struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Recipe.createdAt) private var recipes: [Recipe]

    var body: some View {
        NavigationStack {
            if let recipe = recipes.first {
                RecipeDetailView(recipe: recipe)
            } else {
                ContentUnavailableView("No recipes yet", systemImage: "fork.knife")
            }
        }
        #if DEBUG
        .task {
            if recipes.isEmpty { Recipe.makeSample(in: context) }
        }
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(PersistenceController.previewContainer())
}
