//
//  SampleData.swift
//  RecipeFlow
//

import SwiftData

extension Recipe {
    /// The Bolognese recipe from the design reference, for previews and tests.
    /// Inserts into `context` before touching relationships; SwiftData crashes if a
    /// model that isn't in a context yet reads or writes a to-many relationship.
    @discardableResult
    static func makeSample(in context: ModelContext) -> Recipe {
        let recipe = Recipe(title: "Bolognese Pasta", rawText: "")
        context.insert(recipe)
        let ingredients: [(name: String, quantity: String, unit: String, prep: String, icon: String)] = [
            ("spaghetti", "400", "g", "", "fork.knife"),
            ("ground beef", "400", "g", "", "flame"),
            ("onion", "1", "", "diced", "leaf"),
            ("garlic cloves", "2", "", "minced", "leaf"),
            ("carrot", "1", "", "diced", "carrot"),
            ("celery stalk", "1", "", "diced", "leaf"),
            ("crushed tomatoes", "400", "g can", "", "circle.grid.2x2"),
            ("olive oil", "2", "tbsp", "", "drop"),
            ("salt, pepper, herbs", "", "", "to taste", "cup.and.saucer"),
        ]
        for item in ingredients {
            recipe.addIngredient(Ingredient(name: item.name, quantity: item.quantity, unit: item.unit,
                                            prepNote: item.prep, iconName: item.icon))
        }
        let steps: [(String, String, String)] = [
            ("Prepare veg", "Dice the onion, carrot and celery. Mince the garlic.", "scissors"),
            ("Sauté aromatics", "Heat the olive oil and cook onion and garlic until soft.", "frying.pan"),
            ("Brown beef", "Add the beef and carrot and celery; brown, stirring.", "fork.knife"),
            ("Simmer sauce", "Add tomatoes, season, cover and simmer 30 minutes.", "flame"),
            ("Boil pasta", "Cook spaghetti in salted water until al dente.", "drop"),
            ("Combine & serve", "Toss pasta with the sauce and serve.", "takeoutbag.and.cup.and.straw"),
        ]
        for (index, (title, detail, icon)) in steps.enumerated() {
            recipe.insertStep(Step(title: title, detail: detail, iconName: icon), at: index)
        }
        return recipe
    }
}

enum PersistenceController {
    /// In-memory container for previews and tests.
    @MainActor
    static func previewContainer(withSample: Bool = true) -> ModelContainer {
        let container = try! ModelContainer(
            for: Recipe.self, Ingredient.self, Step.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        if withSample { Recipe.makeSample(in: container.mainContext) }
        return container
    }
}
