//
//  SampleData.swift
//  RecipeFlow
//

import SwiftData

extension Recipe {
    /// The Bolognese recipe from the design reference, for previews and tests.
    static func makeSample() -> Recipe {
        let recipe = Recipe(title: "Bolognese Pasta", rawText: "")
        let ingredients: [(String, String, String, String)] = [
            ("spaghetti", "400", "g", ""),
            ("ground beef", "400", "g", ""),
            ("onion", "1", "", "diced"),
            ("garlic cloves", "2", "", "minced"),
            ("carrot", "1", "", "diced"),
            ("celery stalk", "1", "", "diced"),
            ("crushed tomatoes", "1", "can (400 g)", ""),
            ("olive oil", "2", "tbsp", ""),
            ("salt, pepper, herbs", "", "", "to taste"),
        ]
        for (name, quantity, unit, prep) in ingredients {
            recipe.addIngredient(Ingredient(name: name, quantity: quantity, unit: unit, prepNote: prep))
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
            for: Recipe.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        if withSample { container.mainContext.insert(Recipe.makeSample()) }
        return container
    }
}
