//
//  RecipeFlowApp.swift
//  RecipeFlow
//
//  Created by Kate Kang on 10/24/26.
//

import SwiftUI
import SwiftData

@main
struct RecipeFlowApp: App {
    private let container: ModelContainer

    init() {
        // UI tests pass -inMemoryStore so every run starts with no saved recipes.
        let inMemory = CommandLine.arguments.contains("-inMemoryStore")
        container = try! ModelContainer(
            for: Recipe.self, Ingredient.self, Step.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}
