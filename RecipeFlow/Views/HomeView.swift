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
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.orange)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("RecipeFlow")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .paste:
                    PasteView(onCreate: createRecipe)
                case .recipe(let recipe):
                    RecipeDetailView(recipe: recipe)
                }
            }
        }
    }

    // No parser yet: keep the pasted text on a new recipe and open it for editing.
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
