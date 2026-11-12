//
//  SourceLink.swift
//  RecipeFlow
//

import Foundation

/// Checks and finds the web address a recipe came from. Only http and https are accepted,
/// so a saved link can never be a different kind of URL such as a phone or app scheme.
enum SourceLink {
    private static let schemes: Set<String> = ["http", "https"]
    /// letters, digits and hyphens between dots, ending in a letters-only domain such as "com"
    private static let hostPattern = try! Regex(#"[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}"#)

    /// The address for `text`, adding https:// when it was left off ("youtube.com/watch?v=...").
    static func url(from text: String) -> URL? {
        var candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, !candidate.contains(where: \.isWhitespace) else { return nil }
        if !candidate.contains("://") {
            candidate = "https://" + candidate
        }
        // A username or password in a link ("https://google.com@elsewhere.com") is how links
        // are disguised, and no recipe link needs one.
        guard let url = URL(string: candidate), url.user == nil, url.password == nil,
              let scheme = url.scheme?.lowercased(), schemes.contains(scheme),
              let host = url.host(percentEncoded: false),
              host.wholeMatch(of: hostPattern) != nil else { return nil }
        return url
    }

    /// The first web link in a block of text, such as OCR output with other lines around it.
    static func firstLink(in text: String) -> URL? {
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, options: [], range: range) {
                guard let found = match.url, schemes.contains(found.scheme?.lowercased() ?? ""),
                      let valid = url(from: found.absoluteString) else { continue }
                return valid
            }
        }
        // Browsers often hide "https://", so also try each line on its own.
        for line in text.components(separatedBy: .newlines) {
            if let valid = url(from: line) { return valid }
        }
        return nil
    }
}
