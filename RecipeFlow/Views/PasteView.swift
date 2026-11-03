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
            TextEditor(text: $text)
                .focused($isFocused)
                .accessibilityIdentifier("pasteTextEditor")
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Paste your recipe here")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 17)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }

            Button { onCreate(trimmed) } label: {
                Text("Create recipe")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.orange)
            .disabled(trimmed.isEmpty)
        }
        .padding(16)
        .navigationTitle("Paste recipe")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isFocused = true }
    }
}

#Preview {
    NavigationStack { PasteView { _ in } }
}
