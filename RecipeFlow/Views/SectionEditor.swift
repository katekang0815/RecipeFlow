//
//  SectionEditor.swift
//  RecipeFlow
//

import SwiftUI

/// The parts of a recipe that can be added to or edited as text.
enum RecipeSection: String, Identifiable {
    case ingredients
    case steps
    case notes

    var id: String { rawValue }

    var noun: String { rawValue }

    /// Shown when the text has nothing for this section.
    var emptyMessage: String {
        switch self {
        case .ingredients: "No ingredients found. Put each ingredient on its own line."
        case .steps: "No numbered steps found. Start each step with a number, like 1. 2. 3."
        case .notes: "Write a note, or add a photo of one."
        }
    }
}

/// Add to, or edit, the ingredients, the steps or the notes of a recipe. The text field holds the
/// section's current content (empty when adding); the user can change it, paste more, or add a photo.
/// Only this section is taken from the text, and the screen says what was left out.
/// Notes are kept as written, one line per note line, with no parsing.
struct SectionEditor: View {
    let section: RecipeSection
    let isEditing: Bool
    var onSave: (ParsedRecipe) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(section: RecipeSection, initialText: String, isEditing: Bool, onSave: @escaping (ParsedRecipe) -> Void) {
        self.section = section
        self.isEditing = isEditing
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        let parsed = parse()
        let found = count(in: parsed)

        NavigationStack {
            VStack(spacing: 16) {
                // Save sits on the same line as Add photo.
                TextCaptureView(
                    text: $text,
                    textIdentifier: "sectionEditorText",
                    autoFocus: !isEditing,
                    message: status(parsed, found: found),
                    messageIdentifier: "sectionEditorMessage"
                ) {
                    Button {
                        onSave(parsed)
                        dismiss()
                    } label: {
                        Text("Save").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(found == 0)
                    .accessibilityIdentifier("saveSectionButton")
                }
            }
            .padding(16)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("\(isEditing ? "Edit" : "Add") \(section.noun)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(Theme.ink)
        .presentationDetents([.large])
    }

    private func parse() -> ParsedRecipe {
        switch section {
        case .notes:
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return ParsedRecipe(note: lines)
        case .ingredients:
            return RecipeParser.parse(text, startingWithIngredients: true)
        case .steps:
            return RecipeParser.parse(text)
        }
    }

    private func count(in parsed: ParsedRecipe) -> Int {
        switch section {
        case .ingredients: parsed.ingredients.count
        case .steps: parsed.steps.count
        case .notes: parsed.note.count
        }
    }

    /// What the text holds, so the user knows what Save will do.
    private func status(_ parsed: ParsedRecipe, found: Int) -> String? {
        guard section != .notes else { return nil }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard found > 0 else { return section.emptyMessage }

        var message = "\(plural(found, String(section.noun.dropLast()))) found."
        let others = section == .steps
            ? (parsed.ingredients.count, "ingredient")
            : (parsed.steps.count, "step")
        if others.0 > 0 {
            message += " \(plural(others.0, others.1)) in this text will not be added."
        }
        return message
    }

    private func plural(_ number: Int, _ singular: String) -> String {
        "\(number) \(singular)\(number == 1 ? "" : "s")"
    }
}

#Preview("Add steps") {
    SectionEditor(section: .steps, initialText: "", isEditing: false) { _ in }
}

#Preview("Edit ingredients") {
    SectionEditor(section: .ingredients, initialText: "2 cups flour\nsalt", isEditing: true) { _ in }
}
