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
    /// First sentence of the step.
    var title: String
    /// The rest of the step, if any.
    var detail: String
}

struct ParsedRecipe: Equatable {
    var title: String?
    var ingredients: [ParsedIngredient] = []
    var steps: [ParsedStep] = []
    /// Text under a "Note" header, and anything left after the last numbered step.
    var note: [String] = []
    /// Lines that were neither an ingredient, a step, nor a note, so nothing is dropped silently.
    var ignoredLines: [String] = []
}
