import Foundation

enum TranslationSegment: Equatable {
    /// Text to send to the engine.
    case translate(String)
    /// Already-translated text inserted as is.
    case fixed(String)
}

/// Rewrites Korean notice conventions that engines mistranslate, and keeps the allergy legend out of the engine.
enum TranslationPreprocessor {
    private static let listMarkers = Array("가나다라마바사아자차카타파하")
    private static let latinMarkers = Array("ABCDEFGHIJKLMN")
    private static let weekdays = ["월": "월요일", "화": "화요일", "수": "수요일", "목": "목요일", "금": "금요일", "토": "토요일", "일": "일요일"]

    /// `가.` `나.` … at the start of a line become `A.` `B.` …, and `(금)` becomes `(금요일)`.
    static func normalize(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n").map { line -> String in
            let indent = line.prefix { $0 == " " }
            let rest = line.dropFirst(indent.count)
            guard let first = rest.first, rest.dropFirst().hasPrefix(". "),
                  let index = listMarkers.firstIndex(of: first) else { return line }
            return indent + String(latinMarkers[index]) + rest.dropFirst()
        }
        var result = lines.joined(separator: "\n")
        for (short, full) in weekdays {
            result = result.replacingOccurrences(of: "(\(short))", with: "(\(full))")
        }
        return result
    }

    /// Splits `text` around the allergy legend (`알레르기 정보` + `1.난류 … 19.잣`), which is replaced with the
    /// fixed translation for `target`. Every translatable part is normalized.
    static func segments(_ text: String, target: TargetLanguage) -> [TranslationSegment] {
        let lines = text.components(separatedBy: "\n")
        guard let legendLine = lines.firstIndex(where: isLegendLine) else {
            return [.translate(normalize(text))]
        }
        var start = legendLine
        if let header = lines[..<legendLine].lastIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
           lines[header].contains("알레르기") {
            start = header
        }
        var segments: [TranslationSegment] = []
        let before = trimmedBlock(lines[..<start])
        if !before.isEmpty { segments.append(.translate(normalize(before))) }
        segments.append(.fixed(AllergyLegend.text(for: target)))
        let after = trimmedBlock(lines[(legendLine + 1)...])
        if !after.isEmpty { segments.append(.translate(normalize(after))) }
        return segments
    }

    /// Joins translated parts as separate paragraphs.
    static func join(_ parts: [String]) -> String {
        parts.joined(separator: "\n\n")
    }

    private static func isLegendLine(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        return compact.hasPrefix("1.난류")
    }

    private static func trimmedBlock(_ lines: ArraySlice<String>) -> String {
        lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
