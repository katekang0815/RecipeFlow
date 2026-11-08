//
//  RecipeParser.swift
//  RecipeFlow
//

import Foundation

/// Splits organized recipe text (English or Korean) into ingredients and steps with rules only.
enum RecipeParser {
    static func parse(_ text: String) -> ParsedRecipe {
        var state = ParserState(lines: normalizedLines(text))
        state.run()
        return state.result
    }

    private static func normalizedLines(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { line in
                line.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\u{00A0}" })
                    .joined(separator: " ")
            }
    }
}

// MARK: - State machine

/// Walks the lines top to bottom. Headers and numbering switch between the ingredient and
/// step sections, so the order of the sections in the text does not matter.
private struct ParserState {
    enum Section { case none, ingredients, steps }

    let lines: [String]
    /// When steps are numbered, an unnumbered line is a wrapped continuation of the previous step.
    let hasNumberedSteps: Bool

    var section = Section.none
    var group: String?
    var title: String?
    var ingredients: [ParsedIngredient] = []
    var stepTexts: [String] = []
    var ignored: [String] = []

    init(lines: [String]) {
        self.lines = lines
        hasNumberedSteps = lines.contains { Patterns.numberedStep($0) != nil }
    }

    var result: ParsedRecipe {
        ParsedRecipe(
            title: title,
            ingredients: ingredients,
            steps: stepTexts.filter { !$0.isEmpty }.map(Patterns.makeStep),
            ignoredLines: ignored
        )
    }

    mutating func run() {
        for line in lines {
            if line.isEmpty {
                if section == .ingredients { group = nil }
                continue
            }
            if Patterns.isNoise(line) {
                ignored.append(line)
                continue
            }
            handle(line)
        }
    }

    private mutating func handle(_ line: String) {
        if let text = Patterns.numberedStep(line) {
            // "1. 2 cups flour" in an ingredient list is still an ingredient.
            if section == .ingredients,
               let item = Patterns.ingredient(text, allowTrailing: false) {
                add(item)
                return
            }
            section = .steps
            stepTexts.append(text)
            return
        }

        if let (newSection, rest) = Patterns.header(line) {
            section = newSection
            group = nil
            if let rest { handle(rest) }
            return
        }

        switch section {
        case .none: handleUnsectioned(line)
        case .ingredients: handleIngredient(line)
        case .steps: handleStep(line)
        }
    }

    private mutating func handleUnsectioned(_ line: String) {
        let bullet = Patterns.bulletText(line)
        let body = bullet ?? line

        if let item = Patterns.strictIngredient(body) {
            section = .ingredients
            add(item)
        } else if bullet != nil {
            section = .steps
            stepTexts.append(body)
        } else if title == nil, ingredients.isEmpty, stepTexts.isEmpty,
                  line.count <= 60, !Patterns.endsSentence(line) {
            title = line
        } else {
            ignored.append(line)
        }
    }

    private mutating func handleIngredient(_ line: String) {
        let body = Patterns.bulletText(line) ?? line

        if let name = Patterns.groupName(body) {
            group = name
        } else if let item = Patterns.ingredient(body, allowNameOnly: true) {
            add(item)
        } else if Patterns.endsSentence(body), Patterns.wordCount(body) >= 4 {
            // A real sentence after the list: the steps start here without a header.
            section = .steps
            stepTexts.append(body)
        } else {
            ignored.append(line)
        }
    }

    private mutating func handleStep(_ line: String) {
        let bullet = Patterns.bulletText(line)
        let previousDone = Patterns.endsSentence(stepTexts.last ?? "")

        if bullet == nil, previousDone, let item = Patterns.strictIngredient(line) {
            // Steps first, ingredients after, with no header between them.
            section = .ingredients
            group = nil
            add(item)
        } else if let bullet {
            stepTexts.append(bullet)
        } else if stepTexts.isEmpty || (!hasNumberedSteps && previousDone) {
            stepTexts.append(line)
        } else if stepTexts[stepTexts.count - 1].isEmpty {
            stepTexts[stepTexts.count - 1] = line
        } else {
            stepTexts[stepTexts.count - 1] += " " + line
        }
    }

    private mutating func add(_ parsed: ParsedIngredient) {
        var item = parsed
        // OCR drops blank lines, so a repeated name inside a group means a new group began.
        if let current = group,
           ingredients.contains(where: { $0.group == current && $0.name.lowercased() == item.name.lowercased() }) {
            group = nil
        }
        item.group = group
        ingredients.append(item)
    }
}

// MARK: - Patterns and vocabulary

private enum Patterns {
    // MARK: Vocabulary

    static let ingredientHeaders: Set<String> = [
        "ingredients", "ingredient", "what you need", "you will need",
        "재료", "재료 준비", "준비물", "필요한 재료",
    ]

    static let stepHeaders: Set<String> = [
        "directions", "direction", "instructions", "instruction", "method", "steps", "step",
        "preparation", "procedure", "how to make",
        "만드는 법", "만드는법", "만드는 방법", "조리법", "조리 방법", "조리 순서", "순서", "방법",
    ]

    /// Words that on their own label a sub-recipe, e.g. "양념" above its ingredients.
    static let groupWords: Set<String> = [
        "양념", "양념장", "육수", "반죽", "고명", "토핑", "주재료", "부재료",
    ]

    static let noiseWords: Set<String> = [
        "advertisement", "ad", "ads", "print", "save", "share", "pin", "tweet",
        "jump to recipe", "comments", "reviews",
        "광고", "인쇄", "저장", "공유", "댓글",
    ]

    static let englishUnits = [
        "tablespoons", "tablespoon", "teaspoons", "teaspoon", "tbsp", "tsp",
        "kilograms", "kilogram", "milliliters", "milliliter", "liters", "liter", "litres", "litre",
        "ounces", "ounce", "pounds", "pound", "grams", "gram",
        "cups", "cup", "cloves", "clove", "slices", "slice", "pieces", "piece",
        "sticks", "stick", "sprigs", "sprig", "bunches", "bunch", "handfuls", "handful",
        "packages", "package", "pinches", "pinch", "dashes", "dash", "cans", "can",
        "lbs", "lb", "kg", "mg", "ml", "dl", "oz", "g", "l",
    ]

    static let koreanUnits = [
        "작은술", "큰술", "티스푼", "스푼", "숟가락", "꼬집", "봉지", "포기", "줄기", "마리",
        "공기", "인분", "컵", "개", "알", "쪽", "장", "캔", "줌", "모", "단", "병", "대",
    ]

    // MARK: Regex building blocks (non-capturing, so group numbers stay predictable)

    static let number = #"(?:\d+\s+\d+/\d+|\d+/\d+|\d+(?:[.,]\d+)?[¼½¾⅓⅔⅛⅜⅝⅞]?|[¼½¾⅓⅔⅛⅜⅝⅞])"#
    static let quantity = #"(?:\#(number)(?:\s*[-–~]\s*\#(number))?)"#
    static let unit: String = {
        let english = englishUnits.sorted { $0.count > $1.count }.joined(separator: "|")
        let korean = koreanUnits.sorted { $0.count > $1.count }.joined(separator: "|")
        return "(?:(?:\(english))(?![A-Za-z])|(?:\(korean))(?=\\s|$|[,(]))"
    }()

    // MARK: Regexes

    private static func regex(_ pattern: String) -> Regex<AnyRegexOutput> {
        try! Regex(pattern).ignoresCase()
    }

    static let stepNumber = regex(#"(?:step\s*)?(\d{1,2})\s*[.)\]:](?!\d)\s*(.*)"#)
    static let circledNumber = regex(#"([①-⑳])\s*(.*)"#)
    static let bullet = regex(#"[•·●○▪◦*\-–—]\s+(\S.*)"#)
    static let inlineHeader = regex(#"(.+?)\s*[:：]\s*(\S.*)"#)
    static let parenthetical = regex(#"(.*?)\s*[\(（]([^()（）]*)[\)）]"#)
    static let pageNumber = regex(#"\d{1,3}"#)

    /// "40g bread flour", "1 1/2 cups milk", "2 eggs"
    static let leading = regex(#"(\#(quantity))\s*(\#(unit))?\s*(?:of\s+)?(\S.*)"#)
    /// "밀가루 40g", "계란 2개", "bread flour - 40 g"
    static let trailing = regex(#"(\S.*?)\s*[:：\-–]?\s*(?:약\s*)?(\#(quantity))\s*(\#(unit))"#)
    /// "소금 약간", "salt to taste"
    static let qualitative = regex(#"(\S.*?)\s*[:：,\-–]?\s*(약간|조금|적당량|적당히|to taste)"#)

    // MARK: Helpers

    private static func group(_ match: Regex<AnyRegexOutput>.Match, _ index: Int) -> String? {
        match.output[index].substring.map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    static func wordCount(_ text: String) -> Int {
        text.split(separator: " ").count
    }

    static func endsSentence(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        return ".!?。！？다요".contains(last)
    }

    static func isNoise(_ line: String) -> Bool {
        let lowered = line.lowercased()
        if noiseWords.contains(lowered) { return true }
        if lowered.contains("http://") || lowered.contains("https://") || lowered.contains("www.") { return true }
        return line.wholeMatch(of: pageNumber) != nil
    }

    // MARK: Steps

    /// The text after a step number ("1.", "2)", "Step 3:", "①"), or nil if the line is not numbered.
    static func numberedStep(_ line: String) -> String? {
        if let match = line.wholeMatch(of: stepNumber) { return group(match, 2) }
        if let match = line.wholeMatch(of: circledNumber) { return group(match, 2) }
        return nil
    }

    static func bulletText(_ line: String) -> String? {
        line.wholeMatch(of: bullet).flatMap { group($0, 1) }
    }

    /// First sentence becomes the title, the rest the detail. A period inside a number ("1.5") is not a break.
    static func makeStep(_ text: String) -> ParsedStep {
        if let end = text.range(of: #"[.!?。](?=\s|$)"#, options: .regularExpression) {
            let title = String(text[..<end.lowerBound]).trimmingCharacters(in: .whitespaces)
            let detail = String(text[end.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !title.isEmpty { return ParsedStep(title: title, detail: detail) }
        }
        return ParsedStep(title: text, detail: "")
    }

    // MARK: Headers and groups

    private static let decorations = CharacterSet.whitespaces
        .union(CharacterSet(charactersIn: "[]<>【】《》■□●○◆◇★☆▶▷•·-–—*#:：()（）"))

    private static func headerKey(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s*[\(（][^)）]*[\)）]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: decorations)
            .lowercased()
            .split(separator: " ")
            .joined(separator: " ")
    }

    private static func section(forKey key: String) -> ParserState.Section? {
        if ingredientHeaders.contains(key) { return .ingredients }
        if stepHeaders.contains(key) { return .steps }
        return nil
    }

    /// A section header, alone ("Ingredients", "[재료]") or followed by content on the same line.
    static func header(_ line: String) -> (ParserState.Section, String?)? {
        if let section = section(forKey: headerKey(line)) { return (section, nil) }
        if let match = line.wholeMatch(of: inlineHeader),
           let label = group(match, 1), let rest = group(match, 2),
           let section = section(forKey: headerKey(label)) {
            return (section, rest)
        }
        return nil
    }

    /// A label for the ingredients below it: "Tangzhong:", "[소스]", "■ 양념", or a known word like "양념".
    static func groupName(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let key = headerKey(trimmed)
        if groupWords.contains(key) { return trimmed.trimmingCharacters(in: decorations) }

        if trimmed.hasSuffix(":") || trimmed.hasSuffix("：") {
            let name = trimmed.dropLast().trimmingCharacters(in: .whitespaces)
            if !name.isEmpty, name.count <= 40 { return name }
        }

        let wrappedInBrackets = (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))
            || (trimmed.hasPrefix("【") && trimmed.hasSuffix("】"))
            || (trimmed.hasPrefix("<") && trimmed.hasSuffix(">"))
        let markedWithSymbol = "■□▶▷◆◇".contains(trimmed.first ?? " ")
        if wrappedInBrackets || markedWithSymbol {
            let name = trimmed.trimmingCharacters(in: decorations)
            if !name.isEmpty, wordCount(name) <= 4, !name.contains(where: \.isNumber) { return name }
        }
        return nil
    }

    // MARK: Ingredients

    /// Parses one ingredient line. With `allowNameOnly`, a short phrase with no quantity
    /// ("egg wash", "Tangzhong") is accepted too.
    static func ingredient(
        _ raw: String,
        allowTrailing: Bool = true,
        allowNameOnly: Bool = false
    ) -> ParsedIngredient? {
        var core = raw
        var note = ""
        if let match = core.wholeMatch(of: parenthetical),
           let body = group(match, 1), let inner = group(match, 2) {
            core = body
            note = inner
        }
        core = core.trimmingCharacters(in: .whitespaces)
        guard !core.isEmpty else { return nil }

        if let match = core.wholeMatch(of: leading),
           let quantity = group(match, 1), var name = group(match, 3) {
            var extra = ""
            if let comma = name.firstIndex(of: ",") {
                extra = String(name[name.index(after: comma)...]).trimmingCharacters(in: .whitespaces)
                name = String(name[..<comma]).trimmingCharacters(in: .whitespaces)
            }
            return ParsedIngredient(
                quantity: quantity, unit: group(match, 2) ?? "", name: name,
                note: [note, extra].filter { !$0.isEmpty }.joined(separator: ", ")
            )
        }

        if allowTrailing {
            if let match = core.wholeMatch(of: trailing),
               let name = group(match, 1), let quantity = group(match, 2), let unit = group(match, 3),
               wordCount(name) <= 6 {
                return ParsedIngredient(quantity: quantity, unit: unit, name: name, note: note)
            }
            if let match = core.wholeMatch(of: qualitative),
               let name = group(match, 1), let quantity = group(match, 2) {
                return ParsedIngredient(quantity: quantity, unit: "", name: name, note: note)
            }
        }

        if allowNameOnly, wordCount(core) <= 6, core.count <= 40, !endsSentence(core) {
            return ParsedIngredient(quantity: "", unit: "", name: core, note: note)
        }
        return nil
    }

    /// An ingredient with a quantity that clearly is not a sentence. Used to decide that
    /// a list starts without a header, so it must not catch step text such as "2 hours later".
    static func strictIngredient(_ line: String) -> ParsedIngredient? {
        guard !endsSentence(line), wordCount(line) <= 10,
              let item = ingredient(line), !item.quantity.isEmpty else { return nil }
        return (!item.unit.isEmpty || wordCount(item.name) <= 3) ? item : nil
    }
}
