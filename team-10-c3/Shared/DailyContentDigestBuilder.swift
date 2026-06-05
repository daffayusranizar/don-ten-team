//
//  DailyContentDigestBuilder.swift
//  team-10-c3
//

import Foundation

/// Builds full frame + transcript notes for daily insight prompts (no brief-summary caps).
enum DailyContentDigestBuilder {
    static func sessionFrameLines(screens: [ScreenBreakdownItem]) -> [String] {
        var output: [String] = []
        var lineCounts: [String: Int] = [:]

        for screen in screens {
            let timestamp = ScreenBreakdownItem.formatTimestamp(screen.timestampSeconds)
            let spoken = normalizedSpokenLine(screen.meaningfulAudioTranscript)
            let onScreen = normalizedOnScreenLine(screen.onScreenContent)

            if let summary = screen.contentSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
               !summary.isEmpty {
                let stripped = stripCategoryPrefix(summary)
                if shouldIncludeFrameLine(
                    stripped,
                    spoken: spoken,
                    onScreen: onScreen,
                    lineCounts: &lineCounts
                ) {
                    if let onScreen {
                        output.append("\(timestamp) — \(stripped); on-screen: \(onScreen)")
                    } else {
                        output.append("\(timestamp) — \(stripped)")
                    }
                }
                continue
            }

            var parts: [String] = [screen.categoryLabel]
            if let spoken {
                parts.append("spoken: \(spoken)")
            }
            if let onScreen {
                parts.append("on-screen: \(onScreen)")
            }
            guard parts.count > 1 else { continue }

            let detail = parts.joined(separator: "; ")
            if shouldIncludeFrameLine(
                detail,
                spoken: spoken,
                onScreen: onScreen,
                lineCounts: &lineCounts
            ) {
                output.append("\(timestamp) — \(detail)")
            }
        }

        return Array(output.prefix(12))
    }

    static func sessionTranscriptNotes(digest: String?, brief: String?) -> String? {
        if let digest, let normalized = normalizedTranscriptNotes(digest) {
            return normalized
        }
        if let brief, let normalized = normalizedTranscriptNotes(brief) {
            return normalized
        }
        return nil
    }

    static func fallbackTopicParagraph(from sessions: [DailySessionInsight]) -> String? {
        var paragraphs: [String] = []

        for session in sessions {
            var sessionParts: [String] = []

            let visualThemes = uniqueVisualThemes(from: session.frameLines)
            if !visualThemes.isEmpty {
                sessionParts.append("On screen: \(visualThemes.joined(separator: "; "))")
            }

            if let transcript = session.transcriptNotes, TranscriptSanitizer.isMeaningful(transcript) {
                sessionParts.append("Spoken: \(transcript)")
            }

            guard !sessionParts.isEmpty else { continue }

            if sessions.count > 1 {
                paragraphs.append(
                    "Session \(session.index) (\(session.dominantCategory)): \(sessionParts.joined(separator: ". "))."
                )
            } else {
                paragraphs.append(sessionParts.joined(separator: ". ") + ".")
            }
        }

        guard !paragraphs.isEmpty else { return nil }
        return paragraphs.joined(separator: "\n\n")
    }

    /// Brief, high-level fallback used when LLM daily topic generation is unavailable.
    /// Intentionally avoids specific titles/quotes because per-frame context is limited.
    static func fallbackBriefTopicSentence(from sessions: [DailySessionInsight]) -> String? {
        guard !sessions.isEmpty else { return nil }

        let labels = sessions.map {
            UsageInsightChartCategory.fromPipelineLabel($0.dominantCategory).rawValue.lowercased()
        }
        let counts = Dictionary(grouping: labels, by: { $0 }).mapValues(\.count)
        let ranked = counts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key < rhs.key
        }
        let hasConcern = sessions.contains { session in
            guard let transcript = session.transcriptNotes?.lowercased() else { return false }
            let concernSignals = ["cheat", "fucking", "unethical", "violence", "hate", "kill"]
            return concernSignals.contains(where: transcript.contains)
        }
        let topicHints = fallbackTopicHints(from: sessions)
        guard let primary = ranked.first?.key else { return nil }

        var sentence = "Content leaned mostly toward \(primary)"
        if let secondary = ranked.dropFirst().first?.key {
            sentence += " with a smaller mix of \(secondary)"
        }
        if !topicHints.isEmpty {
            sentence += ", including \(topicHints.joined(separator: ", "))"
        }
        sentence += "."

        if hasConcern {
            sentence += " Some spoken language appeared questionable for a child and may need follow-up."
        }
        return sentence
    }

    static func allTopicLines(from sessions: [DailySessionInsight]) -> [String] {
        var lines: [String] = []
        for session in sessions {
            let duration = DurationFormatting.compact(seconds: session.durationSeconds)
            let header = "Session \(session.index) (\(duration), \(session.dominantCategory)):"
            lines.append(header)

            if TranscriptSanitizer.isMeaningful(session.aiSummary) {
                lines.append("  Session summary: \(session.aiSummary)")
            }

            if let transcript = session.transcriptNotes, TranscriptSanitizer.isMeaningful(transcript) {
                lines.append("  Spoken content: \(transcript)")
            }

            if !TranscriptSanitizer.isMeaningful(session.aiSummary) {
                for frameLine in session.frameLines.prefix(12) {
                    lines.append("  \(frameLine)")
                }
            }
        }
        return lines
    }

    // MARK: - Private

    private static func stripCategoryPrefix(_ summary: String) -> String {
        let separators = [" · ", " - "]
        for separator in separators {
            if let range = summary.range(of: separator) {
                let tail = String(summary[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if TranscriptSanitizer.isMeaningful(tail) {
                    return tail
                }
            }
        }
        return summary
    }

    private static func shouldIncludeFrameLine(
        _ line: String,
        spoken: String?,
        onScreen: String?,
        lineCounts: inout [String: Int]
    ) -> Bool {
        let normalized = normalizeForDedup(line)
        let nextCount = lineCounts[normalized, default: 0] + 1
        lineCounts[normalized] = nextCount

        let spokenIsLowSignal = spoken.map(isLowSignalAudioMarker) ?? false
        let hasOnScreenSignal = onScreen.map(TranscriptSanitizer.isMeaningful) ?? false
        if spokenIsLowSignal && !hasOnScreenSignal {
            return nextCount == 1
        }
        return nextCount <= 2
    }

    private static func normalizedSpokenLine(_ transcript: String?) -> String? {
        guard let transcript else { return nil }
        let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard TranscriptSanitizer.isMeaningful(cleaned) else { return nil }
        guard !isLowSignalAudioMarker(cleaned) else { return nil }
        return cleaned
    }

    private static func normalizedOnScreenLine(_ prompt: String?) -> String? {
        guard let prompt else { return nil }
        let cleaned = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard TranscriptSanitizer.isMeaningful(cleaned) else { return nil }
        return cleaned
    }

    private static func normalizedTranscriptNotes(_ text: String) -> String? {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard TranscriptSanitizer.isMeaningful(cleaned) else { return nil }

        let sentenceSeparators = CharacterSet(charactersIn: ".!?\n")
        let rawSentences = cleaned
            .components(separatedBy: sentenceSeparators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        var kept: [String] = []
        for sentence in rawSentences {
            if isLowSignalAudioMarker(sentence) {
                continue
            }
            let normalized = normalizeForDedup(sentence)
            guard seen.insert(normalized).inserted else { continue }
            kept.append(sentence)
            if kept.count == 4 { break }
        }

        if !kept.isEmpty {
            return kept.joined(separator: ". ") + "."
        }
        return isLowSignalAudioMarker(cleaned) ? nil : cleaned
    }

    private static func normalizeForDedup(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func isLowSignalAudioMarker(_ text: String) -> Bool {
        let normalized = normalizeForDedup(text)
        guard !normalized.isEmpty else { return true }

        let lowSignalPhrases: Set<String> = [
            "music",
            "upbeat music",
            "slowly",
            "applause",
            "clapping",
            "laughter",
            "crowd noise",
            "background music",
            "crickets",
            "silence",
            "no speech"
        ]

        if lowSignalPhrases.contains(normalized) {
            return true
        }

        let parts = normalized.split(separator: " ")
        guard !parts.isEmpty else { return true }
        return parts.allSatisfy { token in
            lowSignalPhrases.contains(String(token))
        }
    }

    private static func fallbackTopicHints(from sessions: [DailySessionInsight]) -> [String] {
        var hints: [String] = []
        var seen = Set<String>()

        for session in sessions {
            for line in session.frameLines {
                guard let phrase = extractVisualPhrase(from: line) else { continue }
                let key = normalizeForDedup(phrase)
                if !phrase.isEmpty, !key.isEmpty, seen.insert(key).inserted {
                    hints.append(phrase.lowercased())
                }
                if hints.count == 3 {
                    return hints
                }
            }
        }

        return hints
    }

    private static func extractVisualPhrase(from line: String) -> String? {
        let lower = line.lowercased()
        let marker = lower.range(of: "on-screen:") ?? lower.range(of: "visual:")
        guard let visualRange = marker else { return nil }

        let visualStart = line.index(
            line.startIndex,
            offsetBy: lower.distance(from: lower.startIndex, to: visualRange.upperBound)
        )
        let raw = String(line[visualStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        let cleaned = raw
            .replacingOccurrences(of: #"^\d{1,2}:\d{2}\s*[-—]?\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\d{1,2}\s*[-—]\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? nil : cleaned
    }

    private static func uniqueVisualThemes(from frameLines: [String]) -> [String] {
        var seen = Set<String>()
        var themes: [String] = []

        for line in frameLines {
            let lower = line.lowercased()
            if let visualRange = lower.range(of: "on-screen: ") ?? lower.range(of: "visual: ") {
                let offset = lower.distance(from: lower.startIndex, to: visualRange.upperBound)
                let start = line.index(line.startIndex, offsetBy: offset)
                let theme = String(line[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
                let key = theme.lowercased()
                if !theme.isEmpty, seen.insert(key).inserted {
                    themes.append(theme)
                }
            } else if !line.contains("spoken:") && !line.contains("on-screen:") {
                let note = line.split(separator: "—", maxSplits: 1).dropFirst().first
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? line
                let key = note.lowercased()
                if TranscriptSanitizer.isMeaningful(note), seen.insert(key).inserted {
                    themes.append(note)
                }
            }
        }
        return themes
    }
}
