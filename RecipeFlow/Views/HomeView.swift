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
    @State private var choosingThumbnail = false

    private let margin: CGFloat = 16
    private let gap: CGFloat = 12

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geometry in
                let side = (geometry.size.width - margin * 2 - gap) / 2
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("My Recipes")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 4)

                        if recipes.isEmpty {
                            // Nothing yet: just the plus, in the middle of the page.
                            addCard
                                .frame(width: side, height: side)
                                .frame(maxWidth: .infinity)
                                .padding(.top, max(0, geometry.size.height / 2 - side - 80))
                        } else {
                            LazyVGrid(columns: [GridItem(.fixed(side), spacing: gap), GridItem(.fixed(side))], spacing: gap) {
                                ForEach(recipes) { recipe in
                                    card(for: recipe).frame(height: side)
                                }
                                addCard.frame(height: side)
                            }
                        }
                    }
                    .padding(.horizontal, margin)
                    .padding(.top, 16)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeFlowView(recipe: recipe)
            }
        }
        .tint(Theme.ink)
        .photoSource(title: "Add a thumbnail", isChoosing: $choosingThumbnail, onImage: addRecipe)
    }

    /// The plus card: choose a picture, and it becomes a new recipe card.
    private var addCard: some View {
        Button { choosingThumbnail = true } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Theme.field)
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add")
        .accessibilityIdentifier("addRecipeButton")
    }

    /// A picture that could not be opened adds nothing.
    private func addRecipe(thumbnail image: UIImage?) {
        guard let image, let data = Recipe.thumbnailData(from: image) else { return }
        let recipe = Recipe()
        context.insert(recipe)
        recipe.thumbnail = data
    }

    private func card(for recipe: Recipe) -> some View {
        Button { path.append(recipe) } label: {
            RecipeCard(recipe: recipe)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recipe.displayTitle + ", " + summary(of: recipe))
        .accessibilityIdentifier("recipeRow")
        .contextMenu {
            Button(role: .destructive) { recipe.delete(from: context) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func summary(of recipe: Recipe) -> String {
        let ingredients = recipe.ingredients.count
        let steps = recipe.steps.count
        return "\(ingredients) ingredient\(ingredients == 1 ? "" : "s") · \(steps) step\(steps == 1 ? "" : "s")"
    }
}

/// A recipe's thumbnail. A recipe without one shows its title.
private struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        Color.clear
            .overlay {
                if let image = recipe.thumbnailImage {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Theme.field.overlay {
                        Text(recipe.displayTitle)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                            .padding(12)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
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
