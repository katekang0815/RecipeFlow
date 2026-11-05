//
//  HomeView.swift
//  RecipeFlow
//

import SwiftUI
import SwiftData

struct HomeView: View {
    private enum Route: Hashable {
        case paste
        case recipe(Recipe)
    }

    @Environment(\.modelContext) private var context
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            Button { path.append(.paste) } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .paste:
                    PasteView(onCreate: createRecipe)
                case .recipe(let recipe):
                    RecipeFlowView(recipe: recipe)
                }
            }
        }
        .tint(Theme.ink)
    }

    // No parser yet: keep the pasted text on a new recipe and open its flow page.
    // The recipe replaces the paste screen so Back returns home.
    private func createRecipe(from text: String) {
        let recipe = Recipe(rawText: text)
        context.insert(recipe)
        path = [.recipe(recipe)]
    }
}

#Preview {
    HomeView()
        .modelContainer(PersistenceController.previewContainer(withSample: false))
}
