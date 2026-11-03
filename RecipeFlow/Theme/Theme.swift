//
//  Theme.swift
//  RecipeFlow
//

import SwiftUI

enum Theme {
    /// Khaki page background from the home screen design.
    static let background = Color(red: 229 / 255, green: 222 / 255, blue: 165 / 255)
    /// Dark brown used for buttons and text.
    static let ink = Color(red: 61 / 255, green: 36 / 255, blue: 30 / 255)
    /// Text fields sit on a lighter panel so the text stays readable on the khaki.
    static let field = Color.white.opacity(0.6)
}

/// Dark brown rounded button with bold white text.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
            .padding(.vertical, 18)
            .padding(.horizontal, 32)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.ink))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

/// Large text input used on the paste and recipe screens.
struct RecipeTextField: View {
    @Binding var text: String
    var identifier: String

    var body: some View {
        TextEditor(text: $text)
            .accessibilityIdentifier(identifier)
            .foregroundStyle(Theme.ink)
            .tint(Theme.ink)
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.field))
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Paste your recipe here")
                        .foregroundStyle(Theme.ink.opacity(0.45))
                        .padding(.horizontal, 17)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
    }
}
