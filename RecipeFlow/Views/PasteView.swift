//
//  PasteView.swift
//  RecipeFlow
//

import SwiftUI

struct PasteView: View {
    var onCreate: (String) -> Void

    @State private var text = ""
    @State private var checkMessage: String?
    @State private var warning = ""
    @State private var showWarning = false

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 16) {
            TextCaptureView(text: $text, textIdentifier: "pasteTextEditor", autoFocus: true, message: checkMessage)

            Button { create() } label: {
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
        .onChange(of: text) { checkMessage = nil }
        .alert("Check your recipe", isPresented: $showWarning) {
            Button("Create anyway") { onCreate(trimmed) }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text(warning)
        }
    }

    /// Only organized recipes get through. Text with no recipe in it is turned away,
    /// and a partial recipe asks first.
    private func create() {
        switch RecipeChecker.check(text: trimmed) {
        case .ready:
            onCreate(trimmed)
        case .partial(let issue):
            warning = issue.message
            showWarning = true
        case .rejected:
            checkMessage = RecipeCheck.rejectedMessage
        }
    }
}

#Preview {
    NavigationStack { PasteView { _ in } }
}
