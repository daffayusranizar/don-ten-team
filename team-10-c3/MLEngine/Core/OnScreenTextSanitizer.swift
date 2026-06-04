import Foundation

/// Filters Vision OCR noise (status bar, screen-recording chrome, social app nav) before parent-facing copy.
public enum OnScreenTextSanitizer {

    private static let systemPhrasePatterns: [String] = [
        "everything on your screen",
        "enable do not disturb",
        "do not disturb",
        "will be recorded",
        "including notifications",
        "unexpected notifications",
        "screen recording",
        "broadcast",
        "replaykit"
    ]

    private static let chromeTokens: Set<String> = [
        "friends", "following", "for you", "live", "explore", "inbox",
        "home", "search", "messages", "profile", "reels", "stories",
        "badung" // common OCR misread of a location chip
    ]

    public static func sanitizeForSummary(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        for phrase in systemPhrasePatterns {
            cleaned = cleaned.replacingOccurrences(
                of: phrase,
                with: "",
                options: [.caseInsensitive, .diacriticInsensitive]
            )
        }

        // Status bar time (e.g. 14.35, 14:35) and battery %
        cleaned = cleaned.replacingOccurrences(
            of: #"\b\d{1,2}[.:]\d{2}\b"#,
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"\b\d{1,3}%\b"#,
            with: "",
            options: .regularExpression
        )

        let tokens = cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { token in
                guard !token.isEmpty else { return false }
                let lower = token.lowercased()
                if chromeTokens.contains(lower) { return false }
                if lower.count <= 2, lower.allSatisfy(\.isNumber) { return false }
                return true
            }

        return tokens.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when sanitized OCR has enough substance to show parents (not just UI chrome).
    public static func isUsefulOnScreenContent(_ text: String) -> Bool {
        let cleaned = sanitizeForSummary(text)
        guard cleaned.count >= 12 else { return false }
        let words = cleaned.split(separator: " ").filter { $0.count > 2 }
        return words.count >= 3 && cleaned.contains { $0.isLetter }
    }
}
