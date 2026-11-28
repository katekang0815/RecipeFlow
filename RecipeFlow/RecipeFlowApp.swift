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
            RootView()
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}

/// The recipes, with the opening screen over them at first.
private struct RootView: View {
    /// It is kept here, so the splash shows when the app starts fresh and not on coming back to it.
    @State private var showsSplash = RootView.startsWithSplash

    /// UI tests (with -inMemoryStore) go straight to the recipes, unless they ask for it with -showSplash.
    private static var startsWithSplash: Bool {
        CommandLine.arguments.contains("-showSplash") || !CommandLine.arguments.contains("-inMemoryStore")
    }

    var body: some View {
        ZStack {
            HomeView()
            if showsSplash {
                // Once the drawing has gone, its plain page fades to show the recipes.
                SplashView { withAnimation(.easeInOut(duration: 0.55)) { showsSplash = false } }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }
}
