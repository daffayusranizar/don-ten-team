import Foundation

public enum ScreenContentSummaryBuilder {
    public static func segmentSummary(
        label: String,
        transcript: String?,
        onScreenTranscript: String? = nil
    ) -> String? {
        var parts: [String] = []

        let category = label
            .replacingOccurrences(of: " content", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !category.isEmpty {
            parts.append(category)
        }

        let spoken = TranscriptSanitizer.sanitize(transcript ?? "")
        if TranscriptSanitizer.isMeaningful(spoken) {
            parts.append("Spoken: \(truncate(spoken, limit: 160))")
        }

        if let onScreen = onScreenTranscript?.trimmingCharacters(in: .whitespacesAndNewlines),
           OnScreenTextSanitizer.isUsefulOnScreenContent(onScreen) {
            parts.append("On screen: \(truncate(onScreen, limit: 120))")
        }

        guard parts.count > 1 || TranscriptSanitizer.isMeaningful(spoken) else { return nil }
        return parts.joined(separator: " · ")
    }

    /// Parent-readable summary when Apple Intelligence is unavailable (no raw OCR dump).
    public static func parentFacingRecordingSummary(
        timeline: [FrameClassificationSummary],
        dominantCategory: String
    ) -> String? {
        guard !timeline.isEmpty else { return nil }

        let segmentCount = timeline.count
        let estimatedMinutes = max(1, (segmentCount * 3) / 60)

        var categoryCounts: [String: Int] = [:]
        for item in timeline {
            let name = item.label
                .replacingOccurrences(of: " content", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            categoryCounts[name, default: 0] += 1
        }

        let sortedCategories = categoryCounts.sorted { $0.value > $1.value }
        let categoryPhrase: String
        if sortedCategories.count <= 1, let only = sortedCategories.first {
            categoryPhrase = only.key.lowercased()
        } else {
            let parts = sortedCategories.prefix(3).map { entry in
                let pct = Int((Double(entry.value) / Double(segmentCount)) * 100)
                return "\(entry.key) (\(pct)%)"
            }
            categoryPhrase = parts.joined(separator: ", ")
        }

        var themes: [String] = []
        for item in timeline {
            if let prompt = item.videoMatchedPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
               !prompt.isEmpty,
               !themes.contains(prompt) {
                themes.append(truncate(prompt, limit: 80))
            }
            if themes.count >= 2 { break }
        }

        if themes.isEmpty {
            let spokenSnippets = timeline.compactMap { item -> String? in
                guard let transcript = item.audioTranscript else { return nil }
                let spoken = TranscriptSanitizer.sanitize(transcript)
                guard TranscriptSanitizer.isQuotableSnippet(spoken) else { return nil }
                return truncate(spoken, limit: 90)
            }
            themes = orderedUnique(spokenSnippets).prefix(2).map { $0 }
        }

        let dominant = dominantCategory
            .replacingOccurrences(of: " content", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        var sentences: [String] = []
        let durationLabel = estimatedMinutes == 1 ? "about a minute" : "about \(estimatedMinutes) minutes"
        sentences.append(
            "During this session (\(durationLabel)), the screen was mostly \(dominant) content."
        )
        if sortedCategories.count > 1 {
            sentences.append("Time broke down as: \(categoryPhrase).")
        }
        if !themes.isEmpty {
            let themeList = themes.joined(separator: "; ")
            sentences.append("Notable themes included \(themeList).")
        }
        sentences.append("Open the screen-by-screen breakdown for more detail.")
        return sentences.joined(separator: " ")
    }

    public static func mergeSegmentSummaries(_ summaries: [String]) -> String? {
        let cleaned = summaries.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return nil }
        return cleaned.max(by: { $0.count < $1.count })
    }

    private static func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let index = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for value in values where seen.insert(value).inserted {
            ordered.append(value)
        }
        return ordered
    }
}
