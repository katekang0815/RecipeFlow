//
//  ParsedRecipe.swift
//  RecipeFlow
//

import Foundation

struct ParsedIngredient: Equatable {
    /// As written: "40", "1 1/2", "½", "2-3", or a phrase like "약간" / "to taste".
    var quantity: String
    var unit: String
    var name: String
    var note: String = ""
    /// Sub-recipe label such as "Tangzhong" or "양념".
    var group: String?
}

struct ParsedStep: Equatable {
    /// First sentence of the numbered line.
    var title: String
    /// The rest of the numbered line, then the bullets listed under it, one per line.
    var detail: String
}

struct ParsedRecipe: Equatable {
    var title: String?
    var ingredients: [ParsedIngredient] = []
    var steps: [ParsedStep] = []
    /// Text under a "Note" header, and every other line that is not an ingredient, a step or a title.
    var note: [String] = []
}
