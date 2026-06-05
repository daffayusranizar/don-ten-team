import Foundation
import FoundationModels

public enum FoundationSummarizerAvailability: Equatable, Sendable {
    case available
    case requiresIOS26
    case unavailable(String)

    public var statusMessage: String? {
        switch self {
        case .available:
            return nil
        case .requiresIOS26:
            return "Apple Intelligence summaries require iOS 26."
        case .unavailable(let reason):
            return reason
        }
    }
}

public enum SummarizerError: LocalizedError {
    case requiresIOS26
    case modelUnavailable(String)
    case emptyInput

    public var errorDescription: String? {
        switch self {
        case .requiresIOS26:
            return "Apple Intelligence summaries require iOS 26."
        case .modelUnavailable(let reason):
            return reason
        case .emptyInput:
            return "Not enough content to summarize."
        }
    }
}

/// A thread-safe actor that chunks up timeline data and feeds it into the iOS 26 on-device Language Model
public actor LLMSummarizer {
    private func instructions(for child: Child?) -> String {
        if let child = child {
            return """
                You are a parental monitoring assistant analyzing a screen recording session for a \(child.currentAge)-year-old named \(child.name).
                Summarize the activity clearly and objectively for a parent.
                Use the child's name (\(child.name)) in the summary to make it personalized.
                Highlight the main apps used and the general themes of the content watched (e.g., educational, gaming, entertainment).
                If session statistics (like duration and percentages) are provided, incorporate them naturally into the summary.
                Use only the provided segment notes and session insights. Do not invent details.
                Write clear, factual prose in 2-4 sentences for a full recording, or 1 sentence for a chunk of segments.
                """
        } else {
            return """
                You are a parental monitoring assistant analyzing a child's screen recording session.
                Summarize the activity clearly and objectively for a parent. 
                Highlight the main apps used and the general themes of the content watched (e.g., educational, gaming, entertainment).
                If session statistics (like duration and percentages) are provided, incorporate them naturally into the summary.
                Use only the provided segment notes and session insights. Do not invent details.
                Write clear, factual prose in 2-4 sentences for a full recording, or 1 sentence for a chunk of segments.
                """
        }
    }

    public init() {}

    public func availability() -> FoundationSummarizerAvailability {
        guard #available(iOS 26, *) else {
            return .requiresIOS26
        }
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .unavailable("This device does not support Apple Intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable("Turn on Apple Intelligence in Settings to generate summaries.")
        case .unavailable(.modelNotReady):
            return .unavailable("The on-device language model is still preparing. Try again shortly.")
        case .unavailable:
            return .unavailable("Apple Intelligence is unavailable right now.")
        @unknown default:
            return .unavailable("Apple Intelligence is unavailable right now.")
        }
    }

    func summarizeDailyInsight(input: DailyInsightInput) async throws -> String {
        guard #available(iOS 26, *) else {
            throw SummarizerError.requiresIOS26
        }
        guard availability() == .available else {
            throw SummarizerError.modelUnavailable(availability().statusMessage ?? "Model unavailable.")
        }

        guard input.totalSessionSeconds > 0 || !input.sessions.isEmpty else {
            throw SummarizerError.emptyInput
        }

        return try await summarizeDailyTopics(input: input)
    }

    @available(iOS 26, *)
    private func summarizeDailyTopics(input: DailyInsightInput) async throws -> String {
        let topicLines = DailyContentDigestBuilder.allTopicLines(from: input.sessions)
        guard !topicLines.isEmpty else { return "" }

        let chunks = chunkLines(topicLines, maxCharacters: 2_800)
        var evidenceNotes: [String] = []

        for chunk in chunks {
            let summary = try await summarizeDailyTopicChunk(chunk, input: input)
            if !summary.isEmpty {
                evidenceNotes.append(summary)
            }
        }

        guard !evidenceNotes.isEmpty else { return "" }

        let mergePrompt = """
        \(dailyMetadataPrompt(input))

        You are given chunk-level evidence notes from one day of child screen activity.
        Generate one parent-facing report using only these notes.
        Never include raw timestamps (for example, 0:09), frame indexes, or line-by-line frame descriptions.
        Do not use prefixes like "visual:" or "spoken:" in the final answer.

        Output format (use exactly):
        Overall Summary:
        <2-4 sentences, plain language, parent-friendly>

        Main Topics:
        - <topic 1>
        - <topic 2>
        - <topic 3>

        Key Messages:
        - <message 1>
        - <message 2>
        - <message 3>

        Potential Concerns:
        - <evidence-based concern 1>
        - <evidence-based concern 2>
        If no concerns: No significant concerns detected.

        Risk Level:
        <Low | Medium | High>

        Parent Recommendation:
        <one short practical recommendation>

        Evidence notes:
        \(evidenceNotes.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        """
        let merged = try await respond(
            prompt: mergePrompt,
            instructions: dailyTopicInstructions(for: input)
        )
        return sanitizeDailyReport(merged)
    }

    @available(iOS 26, *)
    private func summarizeDailyTopicChunk(
        _ lines: [String],
        input: DailyInsightInput
    ) async throws -> String {
        let prompt = """
        \(dailyMetadataPrompt(input))

        Extract concise evidence bullets from this subset of sessions.
        Keep only concrete observations that help a parent understand topics, messages, and concerns.
        Use up to 6 bullet points.
        Do not invent apps, creators, titles, or quoted dialogue not present in the notes.
        Avoid repeating timestamps or percentages.
        Never include timestamps like 0:09 or tokens like "09 —".
        Do not copy frame lines verbatim.
        Prefer content meaning over generic labels.

        \(lines.joined(separator: "\n"))
        """
        return try await respond(
            prompt: prompt,
            instructions: dailyTopicInstructions(for: input)
        )
    }

    public func summarizeRecording(
        timeline: [FrameClassificationSummary],
        overallCategory: String?,
        transcriptBrief: String? = nil,
        child: Child? = nil
    ) async throws -> String {
        guard #available(iOS 26, *) else {
            throw SummarizerError.requiresIOS26
        }
        guard availability() == .available else {
            throw SummarizerError.modelUnavailable(availability().statusMessage ?? "Model unavailable.")
        }

        let statsString = computeSessionStatistics(from: timeline)

        let segmentLines = buildSegmentLines(from: timeline)
        guard !segmentLines.isEmpty else {
            throw SummarizerError.emptyInput
        }

        let chunks = chunkLines(segmentLines, maxCharacters: 2_800)
        var chunkSummaries: [String] = []

        for chunk in chunks {
            let summary = try await summarizeChunk(
                chunk,
                overallCategory: overallCategory,
                statsString: statsString,
                transcriptBrief: transcriptBrief,
                isFinalPass: chunks.count == 1,
                child: child
            )
            if !summary.isEmpty {
                chunkSummaries.append(summary)
            }
        }

        guard !chunkSummaries.isEmpty else {
            throw SummarizerError.emptyInput
        }

        if chunkSummaries.count == 1 {
            return chunkSummaries[0]
        }

        let mergePrompt = """
        \(statsString)
        Combine these partial summaries of one screen recording into one cohesive 2-4 sentence overview. Incorporate key statistics like duration and percentages from the stats above.
        Partial summaries:
        \(chunkSummaries.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        """
        return try await respond(prompt: mergePrompt, child: child)
    }

    @available(iOS 26, *)
    private func summarizeChunk(
        _ lines: [String],
        overallCategory: String?,
        statsString: String,
        transcriptBrief: String?,
        isFinalPass: Bool,
        child: Child?
    ) async throws -> String {
        let categoryLine = overallCategory.map { "Overall classification: \($0)\n" } ?? ""
        let statsLine = isFinalPass ? "\n\(statsString)\n" : ""
        let transcriptLine: String
        if let transcriptBrief, TranscriptSanitizer.isMeaningful(transcriptBrief) {
            transcriptLine = "Spoken content summary: \(transcriptBrief)\n"
        } else {
            transcriptLine = ""
        }
        let prompt: String
        if isFinalPass {
            prompt = """
            \(categoryLine)\(statsLine)\(transcriptLine)Summarize what the user watched in this screen recording based on these time-stamped segment notes and statistics. Naturally mention duration and category percentages when available:

            \(lines.joined(separator: "\n"))
            """
        } else {
            prompt = """
            \(categoryLine)\(transcriptLine)Summarize this portion of a screen recording in 1-2 sentences:

            \(lines.joined(separator: "\n"))
            """
        }
        return try await respond(prompt: prompt, child: child)
    }

    private func dailyTopicInstructions(for input: DailyInsightInput) -> String {
        if let name = input.childName, let age = input.childAge {
            return """
                You are a child screen activity analyst helping parents understand what their child watched.
                The child is \(name), age \(age).
                Your job is to analyze provided sessions and generate an evidence-based parent report.

                Rules:
                - "Educational", "Entertainment", and "Commercial" are content labels only, not quality judgments.
                - Never assume educational content is safe, accurate, or beneficial.
                - Evaluate actual messages, ideas, tone, and modeled behavior.
                - Focus on what a child is likely to remember or imitate.
                - Be factual and avoid speculation.
                - Do not invent creators, titles, apps, or dialogue.
                - Avoid repeating timestamps, frame counts, or percentages unless essential.

                Evaluate whether messages are positive, neutral, questionable, or potentially harmful.
                Flag profanity, mature language, dishonesty encouragement, unsafe behavior, aggression, or harmful beliefs only when supported by evidence.
                """
        }
        return """
            You are a child screen activity analyst helping parents understand what their child watched.
            Your job is to analyze provided sessions and generate an evidence-based parent report.

            Rules:
            - "Educational", "Entertainment", and "Commercial" are content labels only, not quality judgments.
            - Never assume educational content is safe, accurate, or beneficial.
            - Evaluate actual messages, ideas, tone, and modeled behavior.
            - Focus on what a child is likely to remember or imitate.
            - Be factual and avoid speculation.
            - Do not invent creators, titles, apps, or dialogue.
            - Avoid repeating timestamps, frame counts, or percentages unless essential.

            Evaluate whether messages are positive, neutral, questionable, or potentially harmful.
            Flag profanity, mature language, dishonesty encouragement, unsafe behavior, aggression, or harmful beliefs only when supported by evidence.
            """
    }

    private func dailyMetadataPrompt(_ input: DailyInsightInput) -> String {
        var lines: [String] = []
        lines.append("Date: \(input.dayLabel)")
        lines.append("Child age: \(input.childAge.map { String($0) } ?? "unknown")")
        lines.append("Total session time: \(DurationFormatting.verbose(seconds: input.totalSessionSeconds))")
        lines.append("Session count: \(input.sessionCount)")

        if !input.mergedCategoryBreakdown.isEmpty {
            let breakdown = input.mergedCategoryBreakdown.items
                .map { "\($0.name) \($0.percentage)%" }
                .joined(separator: ", ")
            lines.append("Category breakdown: \(breakdown)")
        }

        if input.hasScreenTimeData {
            lines.append("App usage estimate: \(DurationFormatting.verbose(seconds: input.screenTimeAppTotalSeconds))")
            let appLine = input.topApps.prefix(3).map {
                "\($0.displayName): \(DurationFormatting.compact(seconds: $0.durationSeconds))"
            }.joined(separator: ", ")
            if !appLine.isEmpty {
                lines.append("Top apps: \(appLine)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func sanitizeDailyReport(_ text: String) -> String {
        let patterns = [
            #"\b\d{1,2}:\d{2}\b"#,
            #"\b\d{1,2}\s*[—-]\s*"#
        ]

        var cleaned = text
        for pattern in patterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        cleaned = cleaned
            .replacingOccurrences(of: "visual:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "spoken:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }

    @available(iOS 26, *)
    private func respond(
        prompt: String,
        child: Child? = nil,
        instructions customInstructions: String? = nil
    ) async throws -> String {
        let sessionInstructions = customInstructions ?? instructions(for: child)
        let session = LanguageModelSession(instructions: sessionInstructions)
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func computeSessionStatistics(from timeline: [FrameClassificationSummary]) -> String {
        let totalItems = Double(timeline.count)
        guard totalItems > 0 else { return "" }
        
        let interval: Double
        if timeline.count > 1 {
            interval = timeline[1].timestamp - timeline[0].timestamp
        } else {
            interval = 3.0 // default fallback
        }
        
        let totalDurationSeconds = totalItems * interval
        let minutes = Int(totalDurationSeconds) / 60
        let seconds = Int(totalDurationSeconds) % 60
        let durationString = String(format: "%d:%02d", minutes, seconds)
        
        var categoryCounts: [String: Int] = [:]
        
        for item in timeline {
            categoryCounts[item.label, default: 0] += 1
        }
        
        var statsString = "Session Statistics:\n"
        statsString += "- Total estimated duration: \(durationString)\n"
        
        let sortedCategories = categoryCounts.sorted { $0.value > $1.value }
        statsString += "- Content categories watched:\n"
        for (category, count) in sortedCategories {
            let percentage = (Double(count) / totalItems) * 100
            let duration = Double(count) * interval
            let mins = Int(duration) / 60
            let secs = Int(duration) % 60
            let timeStr = mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
            statsString += "  * \(category): \(String(format: "%.0f", percentage))% (\(timeStr))\n"
        }
        
        return statsString
    }

    private func buildSegmentLines(from timeline: [FrameClassificationSummary]) -> [String] {
        timeline.compactMap { entry in
            let timestamp = formatTimestamp(entry.timestamp)
            if let summary = entry.contentSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
                return "\(timestamp) — \(summary)"
            }

            var parts: [String] = [entry.label]
            if let transcript = entry.audioTranscript {
                let spoken = TranscriptSanitizer.sanitize(transcript)
                if TranscriptSanitizer.isMeaningful(spoken) {
                    parts.append("spoken: \(truncate(spoken, limit: 120))")
                }
            }
            if let prompt = entry.videoMatchedPrompt ?? entry.matchedPrompt {
                parts.append("visual: \(truncate(prompt, limit: 100))")
            }
            guard parts.count > 1 else { return "\(timestamp) — \(parts[0])" }
            return "\(timestamp) — \(parts.joined(separator: "; "))"
        }
    }
    private func chunkLines(_ lines: [String], maxCharacters: Int) -> [[String]] {
        guard !lines.isEmpty else { return [] }

        var chunks: [[String]] = []
        var current: [String] = []
        var currentCount = 0

        for line in lines {
            let added = current.isEmpty ? line.count : line.count + 1
            if currentCount + added > maxCharacters, !current.isEmpty {
                chunks.append(current)
                current = [line]
                currentCount = line.count
            } else {
                current.append(line)
                currentCount += added
            }
        }

        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }

    private func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let totalSeconds = max(0, Int(timestamp))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let index = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
