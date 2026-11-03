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
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [Recipe.self, Ingredient.self, Step.self])
    }
}
