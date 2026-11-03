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
            TextEditor(text: $recipe.rawText)
                .accessibilityIdentifier("recipeTextEditor")
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                .overlay(alignment: .topLeading) {
                    if recipe.rawText.isEmpty {
                        Text("Paste your recipe here")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 17)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }

            // The parser will hook in here; for now Create does nothing.
            Button {
            } label: {
                Text("Create")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.orange)
            .disabled(isEmpty)
        }
        .padding(16)
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let container = PersistenceController.previewContainer(withSample: false)
    let recipe = Recipe()
    container.mainContext.insert(recipe)
    return NavigationStack { RecipeDetailView(recipe: recipe) }
        .modelContainer(container)
}
