//
//  StepEditing.swift
//  RecipeFlow
//

import Foundation

/// Pressing Return inside the steps text starts the next step where the cursor is.
enum StepEditing {
    struct Result: Equatable {
        /// The whole text, with the new step in and every step renumbered 1, 2, 3 in order.
        var text: String
        /// Where the cursor goes: in front of the new step's text, counted in characters.
        var caret: Int
    }

    /// `old` is the text before Return was pressed and `new` the text after, with the line break the keyboard
    /// put in. The text after the cursor, up to the end of its line, becomes the next step, and the steps after
    /// it are renumbered. Nil when this is not a Return inside a step, so it stays a plain line break: the text
    /// has no numbered step yet, or the cursor is above the first one.
    /// `caret` is where the cursor ended up in `new`, when known; it tells apart lines breaks that look alike.
    static func splitAtReturn(old: String, new: String, caret: Int? = nil) -> Result? {
        guard let insertedAt = insertionPoint(old: old, new: new, caret: caret) else { return nil }

        // The cursor's line, and where in it the cursor is.
        let oldLines = old.components(separatedBy: "\n")
        var lineIndex = 0
        var column = insertedAt
        for (index, line) in oldLines.enumerated() {
            if column <= line.count { lineIndex = index; break }
            column -= line.count + 1
            lineIndex = index
        }

        let roles = StepParser.roles(of: oldLines.map { StepParser.normalizedLines($0).first ?? "" })
        guard roles[...lineIndex].contains(where: { $0 != .text && $0 != .afterNumber }) else { return nil }

        // Split the cursor's line in two. A cursor in front of the number of a step counts as just after it.
        let line = oldLines[lineIndex]
        let normalized = StepParser.normalizedLines(line).first ?? ""
        var headRole = roles[lineIndex]
        var head = String(line.prefix(column)).trimmingCharacters(in: .whitespaces)
        var tail = String(line.dropFirst(column)).trimmingCharacters(in: .whitespaces)
        if case .start(let rest) = roles[lineIndex] {
            let prefix = max(0, min(normalized.count - rest.count, line.count))
            let restColumn = max(0, column - prefix)
            let headRest = String(rest.prefix(restColumn)).trimmingCharacters(in: .whitespaces)
            tail = String(rest.dropFirst(restColumn)).trimmingCharacters(in: .whitespaces)
            head = headRest
            headRole = headRest.isEmpty ? .numberOnly : .start(rest: headRest)
        } else if roles[lineIndex] == .numberOnly {
            head = ""
            tail = ""
        }

        let lines = Array(oldLines[..<lineIndex]).map { StepParser.normalizedLines($0).first ?? "" }
            + [head, tail] + Array(oldLines[(lineIndex + 1)...]).map { StepParser.normalizedLines($0).first ?? "" }
        let newRoles = Array(roles[..<lineIndex]) + [headRole, tail.isEmpty ? .numberOnly : .start(rest: tail)] + Array(roles[(lineIndex + 1)...])

        var output: [String] = []
        var count = 0
        var caretOffset = 0
        var length = 0
        for (index, line) in lines.enumerated() {
            var written = line
            switch newRoles[index] {
            case .start(let rest):
                count += 1
                written = "\(count). \(rest)"
                if index == lineIndex + 1 { caretOffset = length + "\(count). ".count }
            case .numberOnly:
                count += 1
                written = "\(count). "
                if index == lineIndex + 1 { caretOffset = length + written.count }
            default:
                break
            }
            output.append(written)
            length += written.count + 1
        }
        return Result(text: output.joined(separator: "\n"), caret: caretOffset)
    }

    /// Where, in characters of `old`, the line break was put to make `new`; nil if `new` is not `old` plus one.
    private static func insertionPoint(old: String, new: String, caret: Int?) -> Int? {
        let oldCharacters = Array(old), newCharacters = Array(new)
        guard newCharacters.count == oldCharacters.count + 1 else { return nil }
        let candidates = newCharacters.indices.filter { index in
            newCharacters[index] == "\n" && Array(newCharacters[..<index] + newCharacters[(index + 1)...]) == oldCharacters
        }
        if let caret, candidates.contains(caret - 1) { return caret - 1 }
        return candidates.first
    }
}
