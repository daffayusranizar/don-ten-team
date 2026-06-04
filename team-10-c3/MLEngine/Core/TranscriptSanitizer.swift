import Foundation

/// Strips Whisper control tokens and normalizes transcript text for display and downstream ML.
public enum TranscriptSanitizer {
    private static let specialTokenPattern = /<\|[^|]+\|>/

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
        return cleaned.contains { $0.isLetter }
    }

    /// True when a snippet is long enough to quote in a parent-facing concern signal.
    public static func isQuotableSnippet(_ text: String) -> Bool {
        let cleaned = sanitize(text)
        guard cleaned.count >= 15 else { return false }
        return cleaned.contains { $0.isLetter }
    }
}
