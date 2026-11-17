//
//  Recipe+Display.swift
//  RecipeFlow
//

import Foundation

extension Recipe {
    static let untitledTitle = "Untitled recipe"

    /// What lists show: an empty or blank title shows as "Untitled recipe".
    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Recipe.untitledTitle : title
    }
}
