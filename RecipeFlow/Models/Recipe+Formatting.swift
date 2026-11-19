//
//  Recipe+Formatting.swift
//  RecipeFlow
//

import Foundation

/// The look of parts of a card's text. It is kept with the text it was made for and only applies while the card
/// still has exactly that text, so formatting never lands on the wrong letters.
extension Recipe {
    private var savedFormats: [String: SavedFormat] {
        guard let formatting else { return [:] }
        return (try? JSONDecoder().decode([String: SavedFormat].self, from: formatting)) ?? [:]
    }

    /// The runs saved for a card, when `text` is still the text they were made for.
    func formatRuns(for section: RecipeSection, matching text: String) -> [FormatRun] {
        guard let saved = savedFormats[section.rawValue], saved.text == text else { return [] }
        return saved.runs
    }

    /// Saves the look of a card's text, or forgets it when there is none.
    func setFormat(_ runs: [FormatRun], text: String, for section: RecipeSection) {
        var formats = savedFormats
        if runs.isEmpty || text.isEmpty {
            formats[section.rawValue] = nil
        } else {
            formats[section.rawValue] = SavedFormat(text: text, runs: runs)
        }
        formatting = formats.isEmpty ? nil : try? JSONEncoder().encode(formats)
    }
}
