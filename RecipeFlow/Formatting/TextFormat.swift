//
//  TextFormat.swift
//  RecipeFlow
//

import SwiftUI
import UIKit

/// The colours of the highlighter: each one colours the letters and tints the background behind them.
enum FormatColor: String, Codable, CaseIterable, Identifiable {
    case purple, pink, orange, mint, blue

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var ui: UIColor {
        switch self {
        case .purple: UIColor(red: 0.75, green: 0.27, blue: 0.85, alpha: 1)
        case .pink: UIColor(red: 0.92, green: 0.27, blue: 0.35, alpha: 1)
        case .orange: UIColor(red: 0.95, green: 0.55, blue: 0.20, alpha: 1)
        case .mint: UIColor(red: 0.30, green: 0.72, blue: 0.64, alpha: 1)
        case .blue: UIColor(red: 0.25, green: 0.52, blue: 0.96, alpha: 1)
        }
    }

    var color: Color { Color(ui) }
}

/// How one letter looks.
struct CharStyle: Equatable, Codable {
    var bold = false
    var italic = false
    var underline = false
    var color: FormatColor?

    static let plain = CharStyle()
    var isPlain: Bool { self == .plain }
}

/// A stretch of letters with the same look, counted in UTF-16 units like `NSRange`. Plain stretches are left out.
struct FormatRun: Codable, Equatable {
    var location: Int
    var length: Int
    var style: CharStyle
}

/// The formatting of a card: one look per letter, kept as runs when saved.
enum TextFormat {
    /// One style per UTF-16 unit of a text `count` units long.
    static func styles(from runs: [FormatRun], count: Int) -> [CharStyle] {
        var result = [CharStyle](repeating: .plain, count: max(count, 0))
        for run in runs {
            let start = max(run.location, 0)
            let end = min(run.location + run.length, count)
            guard start < end else { continue }
            for index in start..<end { result[index] = run.style }
        }
        return result
    }

    /// The runs of the letters that are not plain.
    static func runs(from styles: [CharStyle]) -> [FormatRun] {
        var runs: [FormatRun] = []
        var index = 0
        while index < styles.count {
            let style = styles[index]
            var end = index + 1
            while end < styles.count, styles[end] == style { end += 1 }
            if !style.isPlain { runs.append(FormatRun(location: index, length: end - index, style: style)) }
            index = end
        }
        return runs
    }

    /// The styles of `old` carried over to `new`: letters that are still there keep their look, new letters are plain.
    static func map(_ styles: [CharStyle], from old: String, to new: String) -> [CharStyle] {
        let oldUnits = Array(old.utf16), newUnits = Array(new.utf16)
        if oldUnits == newUnits { return styles }
        var result = styles
        // The styles must be as long as the old text for the changes to line up.
        if result.count > oldUnits.count { result.removeLast(result.count - oldUnits.count) }
        while result.count < oldUnits.count { result.append(.plain) }
        for change in newUnits.difference(from: oldUnits) {
            switch change {
            case .remove(let offset, _, _): result.remove(at: offset)
            case .insert(let offset, _, _): result.insert(.plain, at: offset)
            }
        }
        return result
    }

    static func map(_ runs: [FormatRun], from old: String, to new: String) -> [FormatRun] {
        self.runs(from: map(styles(from: runs, count: old.utf16.count), from: old, to: new))
    }

    /// The part of `text` in `range` (UTF-16 units) as text that shows its styles.
    static func attributed(_ text: String, styles: [CharStyle], in range: NSRange) -> AttributedString {
        let units = Array(text.utf16)
        let start = max(range.location, 0)
        let end = min(range.location + range.length, units.count)
        var result = AttributedString()
        var index = start
        while index < end {
            let style = index < styles.count ? styles[index] : .plain
            var stop = index + 1
            while stop < end, (stop < styles.count ? styles[stop] : .plain) == style { stop += 1 }
            var piece = AttributedString(String(decoding: units[index..<stop], as: UTF16.self))
            if !style.isPlain {
                var font = Font.body
                if style.bold { font = font.bold() }
                if style.italic { font = font.italic() }
                piece.font = font
                if style.underline { piece.underlineStyle = .single }
                if let color = style.color {
                    piece.foregroundColor = color.color
                    piece.backgroundColor = color.color.opacity(0.2)
                }
            }
            result.append(piece)
            index = stop
        }
        return result
    }
}

/// Saved formatting of one card, with the text it was made for. It only applies while the card still has that text.
struct SavedFormat: Codable, Equatable {
    var text: String
    var runs: [FormatRun]
}

// MARK: - The text view's side

/// Turning styles into what a `UITextView` shows, and reading them back.
enum TextViewStyle {
    /// Remembers a letter's style on the letter itself, so it travels with typing and edits.
    static let key = NSAttributedString.Key("recipeflow.style")

    static var baseFont: UIFont { UIFont.preferredFont(forTextStyle: .body) }
    static var baseColor: UIColor { UIColor(Theme.ink) }

    static func code(_ style: CharStyle) -> String {
        "\(style.bold ? 1 : 0)\(style.italic ? 1 : 0)\(style.underline ? 1 : 0):\(style.color?.rawValue ?? "")"
    }

    static func style(fromCode code: String) -> CharStyle {
        let parts = code.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 3 else { return .plain }
        let flags = Array(parts[0])
        return CharStyle(
            bold: flags[0] == "1", italic: flags[1] == "1", underline: flags[2] == "1",
            color: FormatColor(rawValue: String(parts[1]))
        )
    }

    static func font(for style: CharStyle) -> UIFont {
        var traits: UIFontDescriptor.SymbolicTraits = []
        if style.bold { traits.insert(.traitBold) }
        if style.italic { traits.insert(.traitItalic) }
        let base = baseFont
        guard !traits.isEmpty, let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else { return base }
        return UIFont(descriptor: descriptor, size: base.pointSize)
    }

    static func attributes(for style: CharStyle) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font(for: style),
            .foregroundColor: style.color?.ui ?? baseColor,
        ]
        if style.underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if let color = style.color { attributes[.backgroundColor] = color.ui.withAlphaComponent(0.2) }
        if !style.isPlain { attributes[key] = code(style) }
        return attributes
    }

    static func attributed(_ text: String, styles: [CharStyle]) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: attributes(for: .plain))
        let length = (text as NSString).length
        var index = 0
        while index < length {
            let style = index < styles.count ? styles[index] : .plain
            var stop = index + 1
            while stop < length, (stop < styles.count ? styles[stop] : .plain) == style { stop += 1 }
            if !style.isPlain {
                result.setAttributes(attributes(for: style), range: NSRange(location: index, length: stop - index))
            }
            index = stop
        }
        return result
    }

    static func styles(of text: NSAttributedString) -> [CharStyle] {
        var result = [CharStyle](repeating: .plain, count: text.length)
        text.enumerateAttribute(key, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard let code = value as? String else { return }
            let style = style(fromCode: code)
            for index in range.location..<(range.location + range.length) { result[index] = style }
        }
        return result
    }

    static func style(fromAttributes attributes: [NSAttributedString.Key: Any]) -> CharStyle {
        (attributes[key] as? String).map(style(fromCode:)) ?? .plain
    }
}
