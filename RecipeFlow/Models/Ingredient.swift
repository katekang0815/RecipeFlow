//
//  Ingredient.swift
//  RecipeFlow
//

import Foundation
import SwiftData

@Model
final class Ingredient {
    var name: String
    var quantity: String   // text, so "1 1/2" and "to taste" survive editing
    var unit: String
    var prepNote: String   // e.g. "diced", "minced"
    var iconName: String   // SF Symbol name
    var sortIndex: Int
    var recipe: Recipe?

    init(name: String = "", quantity: String = "", unit: String = "",
         prepNote: String = "", iconName: String = "carrot", sortIndex: Int = 0) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.prepNote = prepNote
        self.iconName = iconName
        self.sortIndex = sortIndex
    }
}
