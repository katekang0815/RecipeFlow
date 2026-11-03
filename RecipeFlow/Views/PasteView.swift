//
//  PasteView.swift
//  RecipeFlow
//

import SwiftUI

struct PasteView: View {
    var onCreate: (String) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 16) {
            RecipeTextField(text: $text, identifier: "pasteTextEditor")
                .focused($isFocused)

            Button { onCreate(trimmed) } label: {
                Text("Create recipe").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(trimmed.isEmpty)
        }
        .padding(16)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Paste recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .onAppear { isFocused = true }
    }
}

#Preview {
    NavigationStack { PasteView { _ in } }
}
