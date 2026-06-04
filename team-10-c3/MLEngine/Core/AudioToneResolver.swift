import Foundation

/// Cross-modal tone labels when PCM analysis is weak but transcript or screen context indicates speech.
public enum AudioToneResolver {
    private static let tutorialKeywords = [
        "swift", "tutorial", "xcode", "struct", "function", "code", "lesson",
        "learn", "programming", "api", "variable",
    ]

    public static func resolveDisplayTone(
        pcmDescription: String,
        transcript: String?,
        categoryLabel: String?,
        contentSummary: String?
    ) -> String {
        if let stored = TranscriptSanitizer.meaningfulForStorage(transcript ?? "") {
            if AudioToneLabels.isSilentDescription(pcmDescription) {
                return "calm spoken audio, with spoken words"
            }
            return pcmDescription
        }

        if AudioToneLabels.isSilentDescription(pcmDescription),
           isInstructionalContext(categoryLabel: categoryLabel, contentSummary: contentSummary) {
            return "calm spoken tutorial-style audio (inferred from screen)"
        }

        return pcmDescription
    }

    public static func storageTranscript(_ raw: String) -> String? {
        TranscriptSanitizer.meaningfulForStorage(raw)
    }

    private static func isInstructionalContext(
        categoryLabel: String?,
        contentSummary: String?
    ) -> Bool {
        let category = categoryLabel?.lowercased() ?? ""
        if category.contains("educational") {
            return true
        }
        let combined = (contentSummary ?? "").lowercased()
        return tutorialKeywords.contains { combined.contains($0) }
    }
}
