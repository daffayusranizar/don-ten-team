import Foundation

/// Strips Whisper control tokens and normalizes transcript text for display and downstream ML.
public enum TranscriptSanitizer {
    private static let specialTokenPattern = /<\|[^|]+\|>/

    private static let hallucinationPhrases = [
        "thank you for watching",
        "thanks for watching",
        "please subscribe",
        "subscribe to",
        "like and subscribe",
        "see you in the next",
        "you're watching",
    ]

    public static func sanitize(_ text: String) -> String {
        let stripped = text.replacing(specialTokenPattern, with: "")
        return stripped
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when text contains real words after sanitization (not just punctuation or tokens).
    public static func isMeaningful(_ text: String) -> Bool {
        let cleaned = sanitize(text)
        guard cleaned.count >= 3 else { return false }
        guard cleaned.contains(where: \.isLetter) else { return false }
        return !isLikelyHallucination(cleaned)
    }

    /// Common Whisper outputs on near-silent app audio.
    public static func isLikelyHallucination(_ text: String) -> Bool {
        let lower = sanitize(text).lowercased()
        guard !lower.isEmpty else { return true }
        if lower.count < 12 {
            return hallucinationPhrases.contains { lower == $0 || lower.hasPrefix($0) }
        }
        return hallucinationPhrases.contains { lower.contains($0) }
    }

    /// Returns sanitized text for storage/display, or nil if junk or too short.
    public static func meaningfulForStorage(_ text: String) -> String? {
        let cleaned = sanitize(text)
        guard isMeaningful(cleaned) else { return nil }
        return cleaned
    }

    public static func wordCount(_ text: String) -> Int {
        sanitize(text)
            .split { $0.isWhitespace || $0.isNewline }
            .filter { !$0.isEmpty }
            .count
    }

    /// True when a snippet is long enough to quote in a parent-facing concern signal.
    public static func isQuotableSnippet(_ text: String) -> Bool {
        let cleaned = sanitize(text)
        guard cleaned.count >= 15 else { return false }
        guard cleaned.contains(where: \.isLetter) else { return false }
        return !isLikelyHallucination(cleaned)
    }

    /// Strong enough to run session-level sentiment.
    public static func isSubstantialForSentiment(_ text: String) -> Bool {
        let cleaned = sanitize(text)
        guard wordCount(cleaned) >= 8 else { return false }
        guard cleaned.count >= 40 else { return false }
        return isMeaningful(cleaned)
    }
}
