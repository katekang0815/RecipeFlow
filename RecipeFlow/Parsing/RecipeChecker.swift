//
//  RecipeChecker.swift
//  RecipeFlow
//

import Foundation

/// How usable a parsed text is as a recipe.
enum RecipeCheck: Equatable {
    /// Ingredients and steps were both found.
    case ready
    /// Part of a recipe was found. The user may still continue.
    case partial(Issue)
    /// Nothing recipe-like was found.
    case rejected

    enum Issue: Equatable {
        case noIngredients
        case noSteps
        case fewItems(ingredients: Int, steps: Int)
    }

    /// Shown when Create is blocked.
    static let rejectedMessage =
        "This doesn't look like an organized recipe. Add a list of ingredients and the steps, or check the photo."
}

extension RecipeCheck.Issue {
    var message: String {
        switch self {
        case .noIngredients:
            "No ingredients were found. The recipe will have steps only."
        case .noSteps:
            "No numbered steps were found. Start each step with a number, like 1. 2. 3. The recipe will have ingredients only."
        case .fewItems(let ingredients, let steps):
            "Only \(Self.count(ingredients, "ingredient")) and \(Self.count(steps, "step")) were found."
        }
    }

    private static func count(_ number: Int, _ noun: String) -> String {
        "\(number) \(noun)\(number == 1 ? "" : "s")"
    }
}

enum RecipeChecker {
    /// A recipe needs at least this many of each to count as complete.
    static let minimumPerSection = 2

    static func check(_ recipe: ParsedRecipe) -> RecipeCheck {
        let ingredients = recipe.ingredients.count
        let steps = recipe.steps.count

        if ingredients == 0 && steps == 0 { return .rejected }
        if ingredients == 0 { return .partial(.noIngredients) }
        if steps == 0 { return .partial(.noSteps) }
        if ingredients < minimumPerSection || steps < minimumPerSection {
            return .partial(.fewItems(ingredients: ingredients, steps: steps))
        }
        return .ready
    }

    static func check(text: String) -> RecipeCheck {
        check(RecipeParser.parse(text))
    }
}
