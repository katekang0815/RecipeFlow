//
//  RecipeParser.swift
//  RecipeFlow
//

import Foundation

/// Splits organized recipe text (English or Korean) into ingredients, steps and a note with rules only.
///
/// - Ingredients: everything under an "Ingredients" / "재료" header, up to where the steps start.
///   When the ingredients come after the steps, everything below the header.
/// - Steps: only numbered lines, normally 1, 2, 3 in order. Everything that belongs to a numbered
///   step stays with it: wrapped lines, and bullets (•, -) listed under it.
/// - Note: an explicit "Note" section, and every other line that fits nowhere else.
enum RecipeParser {
    /// With `startingWithIngredients`, the text is an ingredient list that has no header above it,
    /// as when the user adds ingredients to an existing recipe.
    static func parse(_ text: String, startingWithIngredients: Bool = false) -> ParsedRecipe {
        var state = ParserState(lines: normalizedLines(text), startingWithIngredients: startingWithIngredients)
        state.run()
        return state.result
    }

    private static func normalizedLines(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "**", with: "")  // bold markers from copied chat text
            .components(separatedBy: "\n")
            .map { line in
                line.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\u{00A0}" })
                    .joined(separator: " ")
            }
    }
}

// MARK: - State machine

/// One numbered step: its numbered line, and the bullets listed under it.
private struct StepDraft {
    var head: String
    var bullets: [String] = []

    /// The text a wrapped line would continue.
    var lastText: String { bullets.last ?? head }

    /// A wrapped line joins the bullet above it, or the numbered line when there are no bullets.
    mutating func append(_ line: String) {
        if bullets.isEmpty {
            head = head.isEmpty ? line : head + " " + line
        } else {
            bullets[bullets.count - 1] += " " + line
        }
    }
}

/// Walks the lines top to bottom. Headers and numbering switch between the sections,
/// so the order of the sections in the text does not matter.
private struct ParserState {
    enum Section { case none, ingredients, steps, note }

    let lines: [String]
    /// Line index to step text, for the numbered lines that count as steps.
    let stepLines: [Int: String]
    /// Past this line no numbered step follows, so leftover text is a note, not a wrapped line.
    let lastStepLine: Int?

    var section: Section
    var group: String?
    var title: String?
    var ingredients: [ParsedIngredient] = []
    var steps: [StepDraft] = []
    var noteLines: [String] = []
    /// A bullet symbol sat alone on its line, so the next line is the bullet's text.
    var bulletPending = false

    init(lines: [String], startingWithIngredients: Bool = false) {
        self.lines = lines
        section = startingWithIngredients ? .ingredients : .none
        stepLines = Patterns.stepLines(in: lines, startingIn: section)
        lastStepLine = stepLines.keys.max()
    }

    var result: ParsedRecipe {
        ParsedRecipe(
            title: title,
            ingredients: ingredients,
            steps: steps.filter { !($0.head.isEmpty && $0.bullets.isEmpty) }.map(Patterns.makeStep),
            note: noteLines
        )
    }

    mutating func run() {
        for (index, line) in lines.enumerated() {
            if line.isEmpty {
                if section == .ingredients { group = nil }
                continue
            }
            // Ads, links and page numbers are not part of the recipe. Links belong in the source link field.
            if Patterns.isNoise(line) { continue }
            handle(line, at: index)
        }
    }

    private mutating func handle(_ line: String, at index: Int?) {
        if let index, let text = stepLines[index] {
            bulletPending = false
            section = .steps
            steps.append(StepDraft(head: text))
            return
        }

        if Patterns.isLoneBullet(line) {
            bulletPending = true
            return
        }
        let bullet = Patterns.bulletText(line)
        let isBullet = bulletPending || bullet != nil
        let text = bullet ?? line
        bulletPending = false

        if let (newSection, rest) = Patterns.header(line) {
            section = newSection
            group = nil
            if let rest { handle(rest, at: nil) }
            return
        }

        switch section {
        case .none: handleUnsectioned(text)
        case .ingredients: handleIngredient(text)
        case .steps: handleStep(text, isBullet: isBullet, at: index)
        case .note: noteLines.append(text)
        }
    }

    private mutating func handleUnsectioned(_ text: String) {
        if let item = Patterns.strictIngredient(text) {
            // An ingredient list that has no header.
            section = .ingredients
            add(item)
        } else if title == nil, ingredients.isEmpty, steps.isEmpty, noteLines.isEmpty,
                  text.count <= 60, !Patterns.endsSentence(text) {
            title = text
        } else {
            noteLines.append(text)
        }
    }

    /// Everything under the ingredients header is an ingredient, even a line with no amount.
    private mutating func handleIngredient(_ text: String) {
        // A numbered ingredient list ("1. 2 cups flour"): the list number is not part of the ingredient.
        var text = text
        if let numbered = Patterns.numberedStep(text),
           Patterns.ingredient(numbered.text, allowTrailing: false) != nil {
            text = numbered.text
        }

        if let name = Patterns.groupName(text) {
            group = name
        } else {
            add(Patterns.ingredient(text, allowNameOnly: true)
                ?? ParsedIngredient(quantity: "", unit: "", name: text))
        }
    }

    /// A line in the steps section that is not itself numbered.
    private mutating func handleStep(_ text: String, isBullet: Bool, at index: Int?) {
        guard !steps.isEmpty else {
            // Under a "Steps" header but before the first numbered step: unnumbered text is not a step.
            noteLines.append(text)
            return
        }

        if isBullet {
            steps[steps.count - 1].bullets.append(text)  // a bullet belongs to the numbered step above it
        } else if let index, let lastStepLine, index < lastStepLine {
            steps[steps.count - 1].append(text)  // another numbered step follows, so this is part of this one
        } else if !Patterns.endsSentence(steps[steps.count - 1].lastText) {
            steps[steps.count - 1].append(text)  // the last step wrapped onto this line
        } else if let item = Patterns.strictIngredient(text) {
            // Steps first, ingredients after, with no header between them.
            section = .ingredients
            group = nil
            add(item)
        } else {
            section = .note
            noteLines.append(text)
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

    static let noteHeaders: Set<String> = [
        "note", "notes", "memo", "tip", "tips",
        "참고", "참고사항", "메모", "비고", "팁",
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
    static let loneBullet = regex(#"[•·●○▪◦*\-–—]"#)
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

    /// Ads, links and page numbers.
    static func isNoise(_ line: String) -> Bool {
        let lowered = line.lowercased()
        if noiseWords.contains(lowered) { return true }
        if lowered.contains("http://") || lowered.contains("https://") || lowered.contains("www.") { return true }
        return line.wholeMatch(of: pageNumber) != nil
    }

    // MARK: Steps

    /// The number and text of a numbered line ("1.", "2)", "Step 3:", "①"), or nil if it is not numbered.
    static func numberedStep(_ line: String) -> (number: Int, text: String)? {
        if let match = line.wholeMatch(of: stepNumber),
           let digits = group(match, 1), let number = Int(digits), let text = group(match, 2) {
            return (number, text)
        }
        if let match = line.wholeMatch(of: circledNumber),
           let circled = group(match, 1)?.unicodeScalars.first, let text = group(match, 2) {
            return (Int(circled.value) - 0x2460 + 1, text)
        }
        return nil
    }

    /// The numbered lines that count as steps: each number is higher than the one before it,
    /// or a restart at 1 (a second list for another part of the recipe). The list does not have
    /// to begin at 1, since a cropped photo can start mid-recipe. A numbered line that goes
    /// backwards is left as plain text. Numbered lines inside a note, or numbered ingredients
    /// ("1. 2 cups flour"), are not steps.
    static func stepLines(in lines: [String], startingIn start: ParserState.Section = .none) -> [Int: String] {
        var result: [Int: String] = [:]
        var previous: Int?
        var section = start

        for (index, line) in lines.enumerated() where !line.isEmpty && !isNoise(line) {
            guard let (number, text) = numberedStep(line) else {
                if let (newSection, _) = header(line) { section = newSection }
                continue
            }
            if section == .note { continue }
            if section == .ingredients, ingredient(text, allowTrailing: false) != nil { continue }
            if let previous, number <= previous, number != 1 { continue }
            result[index] = text
            previous = number
        }
        return result
    }

    static func isLoneBullet(_ line: String) -> Bool {
        line.wholeMatch(of: loneBullet) != nil
    }

    static func bulletText(_ line: String) -> String? {
        line.wholeMatch(of: bullet).flatMap { group($0, 1) }
    }

    /// The step's numbered line gives the title (its first sentence) and the start of the detail;
    /// the bullets under it follow, one per line.
    static func makeStep(_ draft: StepDraft) -> ParsedStep {
        if draft.head.isEmpty, let first = draft.bullets.first {
            return ParsedStep(title: first, detail: bulletLines(Array(draft.bullets.dropFirst())))
        }
        var step = splitFirstSentence(draft.head)
        step.detail = [step.detail, bulletLines(draft.bullets)].filter { !$0.isEmpty }.joined(separator: "\n")
        return step
    }

    private static func bulletLines(_ bullets: [String]) -> String {
        bullets.map { "• " + $0 }.joined(separator: "\n")
    }

    /// First sentence becomes the title, the rest the detail. A period inside a number ("1.5") is not a break.
    private static func splitFirstSentence(_ text: String) -> ParsedStep {
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
        if noteHeaders.contains(key) { return .note }
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
