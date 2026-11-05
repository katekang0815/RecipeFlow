//
//  RecipeFlowView.swift
//  RecipeFlow
//

import SwiftUI
import SwiftData

/// Shown after Create. Placeholder sections for now; the parser will fill them in.
struct RecipeFlowView: View {
    var recipe: Recipe

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section("Ingredients", placeholder: "Ingredients will appear here")
                section("Steps", placeholder: "Steps will appear here")
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private func section(_ title: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.ink)

            Text(placeholder)
                .foregroundStyle(Theme.ink.opacity(0.45))
                .frame(maxWidth: .infinity, minHeight: 140)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(title.lowercased() + "Section")
    }
}

#Preview {
    let container = PersistenceController.previewContainer(withSample: false)
    let recipe = Recipe()
    container.mainContext.insert(recipe)
    return NavigationStack { RecipeFlowView(recipe: recipe) }
        .modelContainer(container)
}
