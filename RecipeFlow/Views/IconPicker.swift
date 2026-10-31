//
//  IconPicker.swift
//  RecipeFlow
//

import SwiftUI

/// Tap the icon to choose a different SF Symbol.
struct IconPicker: View {
    @Binding var iconName: String
    let options: [String]
    var size: CGFloat = 44

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { name in
                Button { iconName = name } label: { Label(name, systemImage: name) }
            }
        } label: {
            Image(systemName: IconCatalog.resolved(iconName))
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.orange.opacity(0.15)))
                .overlay(Circle().stroke(Color.orange.opacity(0.6), lineWidth: 1.5))
        }
        .buttonStyle(.borderless)
    }
}
