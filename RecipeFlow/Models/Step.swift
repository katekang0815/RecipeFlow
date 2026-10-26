//
//  Step.swift
//  RecipeFlow
//

import Foundation
import SwiftData

@Model
final class Step {
    var title: String
    var detail: String
    var iconName: String   // SF Symbol name
    var sortIndex: Int
    var recipe: Recipe?

    init(title: String = "", detail: String = "",
         iconName: String = "fork.knife", sortIndex: Int = 0) {
        self.title = title
        self.detail = detail
        self.iconName = iconName
        self.sortIndex = sortIndex
    }
}
