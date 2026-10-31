//
//  RecipeDetailView.swift
//  RecipeFlow
//

import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    @Bindable var recipe: Recipe
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            Section {
                TextField("Recipe title", text: $recipe.title, axis: .vertical)
                    .font(.title2.bold())
            }

            Section("Ingredients") {
                ForEach(recipe.sortedIngredients) { ingredient in
                    IngredientRow(ingredient: ingredient)
                }
                .onDelete { recipe.deleteIngredients(at: $0, in: context) }

                Button {
                    recipe.addIngredient(Ingredient())
                } label: {
                    Label("Add ingredient", systemImage: "plus.circle")
                }
            }

            Section("Steps") {
                let steps = recipe.sortedSteps
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    StepRow(step: step, number: index + 1, isLast: index == steps.count - 1)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .swipeActions(edge: .leading) {
                            Button {
                                recipe.insertStep(newStep(), at: index + 1)
                            } label: {
                                Label("Insert below", systemImage: "plus")
                            }
                            .tint(.orange)
                        }
                        .contextMenu {
                            Button { recipe.insertStep(newStep(), at: index) } label: {
                                Label("Insert above", systemImage: "arrow.up.to.line")
                            }
                            Button { recipe.insertStep(newStep(), at: index + 1) } label: {
                                Label("Insert below", systemImage: "arrow.down.to.line")
                            }
                            Button(role: .destructive) {
                                recipe.deleteSteps(at: IndexSet(integer: index), in: context)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .onDelete { recipe.deleteSteps(at: $0, in: context) }
                .onMove { recipe.moveSteps(from: $0, to: $1) }

                Button {
                    recipe.insertStep(newStep(), at: recipe.steps.count)
                } label: {
                    Label("Add step", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
    }

    private func newStep() -> Step {
        Step(title: "New step", detail: "", iconName: "fork.knife")
    }
}

#Preview {
    let container = PersistenceController.previewContainer()
    let recipe = try! container.mainContext.fetch(FetchDescriptor<Recipe>()).first!
    return NavigationStack { RecipeDetailView(recipe: recipe) }
        .modelContainer(container)
}
