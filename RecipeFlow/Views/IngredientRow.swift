//
//  IngredientRow.swift
//  RecipeFlow
//

import SwiftUI

struct IngredientRow: View {
    @Bindable var ingredient: Ingredient

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconPicker(iconName: $ingredient.iconName, options: IconCatalog.ingredientIcons, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    TextField("Qty", text: $ingredient.quantity)
                        .frame(width: 44)
                        .multilineTextAlignment(.trailing)
                    TextField("Unit", text: $ingredient.unit)
                        .frame(width: 72)
                    TextField("Ingredient", text: $ingredient.name, axis: .vertical)
                }
                TextField("Prep (e.g. diced)", text: $ingredient.prepNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
