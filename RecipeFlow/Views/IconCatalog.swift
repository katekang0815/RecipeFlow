//
//  IconCatalog.swift
//  RecipeFlow
//

import UIKit

/// SF Symbols offered in the icon pickers. Names missing on the running OS are dropped
/// so a symbol that isn't available on iOS 17 never renders as an empty image.
enum IconCatalog {
    private static let stepCandidates = [
        "scissors", "frying.pan", "flame", "drop", "timer", "fork.knife", "oven",
        "refrigerator", "cup.and.saucer", "takeoutbag.and.cup.and.straw", "thermometer.medium",
        "list.bullet.clipboard",
    ]
    private static let ingredientCandidates = [
        "carrot", "leaf", "fish", "drop", "flame", "cup.and.saucer", "fork.knife", "circle.grid.2x2",
    ]

    static let stepIcons = stepCandidates.filter(isAvailable)
    static let ingredientIcons = ingredientCandidates.filter(isAvailable)

    static func isAvailable(_ name: String) -> Bool {
        UIImage(systemName: name) != nil
    }

    static func resolved(_ name: String, fallback: String = "fork.knife") -> String {
        isAvailable(name) ? name : fallback
    }
}
