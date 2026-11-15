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
    @State private var searching = false
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private let margin: CGFloat = 16
    private let gap: CGFloat = 12

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geometry in
                let side = (geometry.size.width - margin * 2 - gap) / 2
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("My Recipes")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            searchButton
                        }
                        .padding(.horizontal, 4)

                        if searching { searchField }

                        if recipes.isEmpty {
                            // Nothing yet: just the plus, in the middle of the page.
                            addCard
                                .frame(width: side, height: side)
                                .frame(maxWidth: .infinity)
                                .padding(.top, max(0, geometry.size.height / 2 - side - 80))
                        } else {
                            LazyVGrid(columns: [GridItem(.fixed(side), spacing: gap), GridItem(.fixed(side))], spacing: gap) {
                                ForEach(shownRecipes) { recipe in
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

    /// Recipes whose title contains the search text. With nothing typed, every recipe shows.
    private var shownRecipes: [Recipe] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return recipes }
        return recipes.filter { $0.title.localizedCaseInsensitiveContains(text) }
    }

    /// A magnifying glass at the right end of the heading line; tapping it opens or closes the field.
    private var searchButton: some View {
        Button {
            searching.toggle()
            if searching { searchFocused = true } else { query = "" }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Search")
        .accessibilityIdentifier("searchButton")
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.ink.opacity(0.5))
            TextField("", text: $query, prompt: Text("Search recipes").foregroundStyle(Theme.ink.opacity(0.45)))
                .foregroundStyle(Theme.ink)
                .tint(Theme.ink)
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .accessibilityIdentifier("searchField")
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.ink.opacity(0.5))
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.field))
        .padding(.horizontal, 4)
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
