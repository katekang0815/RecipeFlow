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
    /// The recipe whose thumbnail is being changed, or nil when a picture makes a new recipe.
    @State private var thumbnailTarget: Recipe?
    /// The recipe whose small menu (Delete, Edit thumbnail) is open on its card.
    @State private var menuRecipe: Recipe?
    @State private var searching = false
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private let margin: CGFloat = 16
    private let gap: CGFloat = 12

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geometry in
                let side = (geometry.size.width - margin * 2 - gap) / 2
                VStack(alignment: .leading, spacing: 16) {
                    // The title and the search stay where they are; only the cards scroll.
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
                    }
                    .padding(.horizontal, margin)
                    .padding(.top, 16)
                    // A tap beside the buttons closes an open card menu.
                    .background(Color.clear.contentShape(Rectangle()).onTapGesture { closeMenu() })

                    ScrollView {
                        // With no recipes the plus card is centered on the page instead, see below.
                        if showsNameList {
                            // Search open with nothing typed yet: the names of the recipes, stacked, with no thumbnails.
                            LazyVStack(spacing: 8) {
                                ForEach(shownRecipes) { recipe in
                                    nameRow(for: recipe)
                                }
                            }
                            .padding(.horizontal, margin)
                        } else if !recipes.isEmpty {
                            LazyVGrid(columns: [GridItem(.fixed(side), spacing: gap), GridItem(.fixed(side))], spacing: gap) {
                                ForEach(shownRecipes) { recipe in
                                    card(for: recipe).frame(height: side)
                                }
                                addCard.frame(height: side)
                            }
                            .padding(.horizontal, margin)
                            // The gaps between the cards close an open card menu.
                            .background(Color.clear.contentShape(Rectangle()).onTapGesture { closeMenu() })
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .overlay {
                    if recipes.isEmpty, !showsNameList {
                        // In the middle of the screen, the same size as a card in the grid.
                        addCard
                            .frame(width: side, height: side)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeFlowView(recipe: recipe)
            }
        }
        .tint(Theme.ink)
        .photoSource(
            title: thumbnailTarget == nil ? "Add a thumbnail" : "Edit thumbnail",
            isChoosing: $choosingThumbnail,
            cropsLibraryPhotos: true,
            onImage: addOrReplaceThumbnail
        )
    }

    /// The search is open and nothing is typed: the recipes show as a list of names. Typing filters the cards.
    private var showsNameList: Bool {
        searching && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        Button {
            thumbnailTarget = nil
            choosingThumbnail = true
        } label: {
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

    /// A picture makes a new recipe card, or replaces the thumbnail of the card being edited.
    /// A picture that could not be opened changes nothing.
    private func addOrReplaceThumbnail(_ image: UIImage?) {
        let target = thumbnailTarget
        thumbnailTarget = nil
        guard let image, let data = Recipe.thumbnailData(from: image) else { return }
        if let target {
            target.thumbnail = data
        } else {
            let recipe = Recipe()
            context.insert(recipe)
            recipe.thumbnail = data
        }
    }

    private func card(for recipe: Recipe) -> some View {
        // Not a Button: a Button takes the touch as a tap even after a long hold, which opened the recipe
        // instead of the menu. A tap and a hold on a plain view are told apart properly.
        RecipeCard(recipe: recipe)
            // A tap opens the recipe and a hold opens the menu; a hold is never also a tap.
            .overlay(
                CardTouch(
                    onTap: {
                        // With a menu open, a tap only closes it.
                        if menuRecipe != nil { menuRecipe = nil } else { path.append(recipe) }
                    },
                    onHold: { menuRecipe = recipe }
                )
            )
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(recipe.displayTitle + ", " + summary(of: recipe))
            .accessibilityIdentifier("recipeRow")
        .overlay(alignment: .bottomTrailing) {
            if menuRecipe === recipe { cardMenu(for: recipe) }
        }
    }

    private func closeMenu() { menuRecipe = nil }

    /// A recipe as just its name, for the search list.
    private func nameRow(for recipe: Recipe) -> some View {
        Button { path.append(recipe) } label: {
            Text(recipe.displayTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.field))
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recipe.displayTitle + ", " + summary(of: recipe))
        .accessibilityIdentifier("recipeRow")
    }

    /// Delete and Edit thumbnail, in a small panel at the bottom right of the card.
    private func cardMenu(for recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            menuRow("Delete", systemImage: "trash", color: .red, id: "deleteRecipeButton") {
                menuRecipe = nil
                recipe.delete(from: context)
            }
            Divider()
            menuRow("Edit thumbnail", systemImage: "pencil", color: Theme.ink, id: "editThumbnailButton") {
                menuRecipe = nil
                thumbnailTarget = recipe
                choosingThumbnail = true
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(8)
    }

    private func menuRow(_ title: String, systemImage: String, color: Color, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title).lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(.system(size: 15))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func summary(of recipe: Recipe) -> String {
        let ingredients = recipe.ingredients.filter { !$0.name.isEmpty || !$0.quantity.isEmpty }.count
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

/// Catches a tap and a hold on a card. The tap waits to see whether the touch becomes a hold, so a hold is
/// not also a tap.
private struct CardTouch: UIViewRepresentable {
    var onTap: () -> Void
    var onHold: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let hold = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.held(_:)))
        hold.minimumPressDuration = 0.4
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped))
        tap.require(toFail: hold)
        view.addGestureRecognizer(hold)
        view.addGestureRecognizer(tap)
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onHold = onHold
    }

    final class Coordinator: NSObject {
        var onTap: () -> Void = {}
        var onHold: () -> Void = {}

        @objc func tapped() { onTap() }

        @objc func held(_ recognizer: UILongPressGestureRecognizer) {
            if recognizer.state == .began { onHold() }
        }
    }
}
