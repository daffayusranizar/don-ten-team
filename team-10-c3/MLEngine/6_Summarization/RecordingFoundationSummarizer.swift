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
        let childContext: String?
        if let child = child {
            childContext = "The child is \(child.name), age \(child.currentAge)."
        } else {
            childContext = nil
        }
        return analystFrameworkInstructions(childContext: childContext)
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
        Generate one parent-facing report using only these notes and metadata.
        Review all sessions together before deciding repeated topics/messages.
        Focus on repeated patterns across sessions, not isolated moments.
        Never include raw timestamps (for example, 0:09), frame indexes, or line-by-line frame descriptions.
        Do not use prefixes like "visual:" or "spoken:" in the final answer.
        Do not use prefixes like "on-screen:" in the final answer.
        Do not invent creators, titles, apps, dialogue, or claims not present in the notes.

        Output format (use exactly):
        Overall Summary:
        <2-4 sentences, plain language, parent-friendly>

        Topics Repeated Most Often:
        - <topic 1>
        - <topic 2>
        - <topic 3>

        Key Messages Repeated Most Often:
        - <message 1>
        - <message 2>
        - <message 3>

        What Appears To Hold Attention:
        <2-3 sentences using cautious language like "appears drawn to", "may be interested in", "repeatedly viewed", "frequently exposed to". Base this on repeated topics/messages/formats and total viewing time patterns.>

        Evidence Summary:
        - <strongest evidence point 1>
        - <strongest evidence point 2>
        - <strongest evidence point 3>

        Potential Concerns:
        - <evidence-based concern 1>
        - <evidence-based concern 2>
        If no concerns: No significant concerns detected.


        Parent Recommendation:
        <one short practical recommendation>

        Evidence notes:
        \(evidenceNotes.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        write a natural language report with no bullet points and no evidence notes.
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

        Extract concise evidence bullets from this subset of sessions for a later merged parent report.
        Keep only concrete observations that help identify repeated topics, repeated messages, attention signals, and concerns.
        Use up to 8 bullet points.
        Do not invent apps, creators, titles, or quoted dialogue not present in the notes.
        Avoid repeating timestamps or percentages.
        Never include timestamps like 0:09 or tokens like "09 —".
        Do not copy frame lines verbatim.
        Prefer content meaning over generic labels.
        If audio and visual/on-screen cues disagree, prioritize audio meaning.
        When on-screen OCR or on-screen summary text is present, include a brief interpretation of what the screen showed.
        Include message-quality indicators when supported: Positive, Neutral, Questionable, Potentially Harmful.

        \(lines.joined(separator: "\n"))
        """
        return try await respond(
            prompt: prompt,
            instructions: dailyTopicInstructions(for: input)
        )
    }

    /// Writes one brief parent-friendly on-screen summary per timeline segment from OCR text.
    @available(iOS 26, *)
    public func summarizeOnScreenBriefs(
        segments: [(id: Int, ocr: String, category: String)]
    ) async -> [Int: String] {
        guard #available(iOS 26, *) else { return [:] }
        guard availability() == .available, !segments.isEmpty else { return [:] }

        let chunks = chunkLines(
            segments.enumerated().map { offset, segment in
                "\(offset + 1). [\(segment.category)] OCR: \(truncate(segment.ocr, limit: 360))"
            },
            maxCharacters: 2_400
        )

        var summaries: [Int: String] = [:]
        var segmentOffset = 0

        for chunk in chunks {
            let prompt = """
            For each numbered item, write one brief sentence summarizing what appears on screen based ONLY on the OCR text.
            Use plain parent-friendly language. Do not invent creators, titles, apps, or dialogue not present in the OCR.
            If OCR is too sparse to interpret, reply with "Unclear on-screen content" for that item.
            Reply with numbered lines only in this format:
            1: <summary>
            2: <summary>

            \(chunk.joined(separator: "\n"))
            """
            do {
                let response = try await respond(
                    prompt: prompt,
                    instructions: onScreenBriefInstructions()
                )
                let parsed = parseNumberedOnScreenBriefs(response)
                for (lineNumber, summary) in parsed {
                    let index = segmentOffset + lineNumber - 1
                    guard segments.indices.contains(index) else { continue }
                    let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    summaries[segments[index].id] = trimmed
                }
            } catch {
                continue
            }
            segmentOffset += chunk.count
        }

        return summaries
    }

    public func summarizeRecording(
        timeline: [FrameClassificationSummary],
        overallCategory: String?,
        transcriptBrief: String? = nil,
        transcriptEvidence: String? = nil,
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
                transcriptEvidence: transcriptEvidence,
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

        if chunks.count == 1, let only = chunkSummaries.first {
            return sanitizeDailyReport(only)
        }

        let sessionMetadata = sessionMetadataPrompt(
            statsString: statsString,
            overallCategory: overallCategory,
            transcriptBrief: transcriptBrief,
            transcriptEvidence: transcriptEvidence
        )

        let mergePrompt = """
        \(sessionMetadata)

        You are given chunk-level evidence notes from one child screen recording session.
        Generate one parent-facing report using only these notes and metadata.
        Focus on content meaning and repeated messages, not labels.
        Prioritize spoken content when audio and on-screen/visual cues conflict.
        Never include raw timestamps (for example, 0:09), frame indexes, or line-by-line frame descriptions.
        Do not use prefixes like "visual:" or "spoken:" in the final answer.
        Do not use prefixes like "on-screen:" in the final answer.
        Do not invent creators, titles, apps, dialogue, or claims not present in the notes.

        Output format (use exactly):
        Overall Summary:
        <2-4 sentences, plain language, parent-friendly>

        Topics Repeated Most Often:
        - <topic 1>
        - <topic 2>
        - <topic 3>

        Key Messages Repeated Most Often:
        - <message 1>
        - <message 2>
        - <message 3>

        What Appears To Hold Attention:
        <2-3 sentences using cautious language like "appears drawn to", "may be interested in", "repeatedly viewed", "frequently exposed to". Base this on repeated topics/messages/formats and total viewing time patterns.>

        Evidence Summary:
        - <strongest evidence point 1>
        - <strongest evidence point 2>
        - <strongest evidence point 3>

        Potential Concerns:
        - <evidence-based concern 1>
        - <evidence-based concern 2>
        If no concerns: No significant concerns detected.

        Parent Recommendation:
        <one short practical recommendation>

        Evidence notes:
        \(chunkSummaries.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        TASK:
        write a natural language report with no bullet points and no evidence notes.
        """
        let merged = try await respond(
            prompt: mergePrompt,
            instructions: instructions(for: child)
        )
        return sanitizeDailyReport(merged)
    }

    @available(iOS 26, *)
    private func summarizeChunk(
        _ lines: [String],
        overallCategory: String?,
        statsString: String,
        transcriptBrief: String?,
        transcriptEvidence: String?,
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
        let transcriptEvidenceLine: String
        if let transcriptEvidence, TranscriptSanitizer.isMeaningful(transcriptEvidence) {
            transcriptEvidenceLine = "Transcript evidence:\n\(transcriptEvidence)\n"
        } else {
            transcriptEvidenceLine = ""
        }
        let prompt: String
        if isFinalPass {
            prompt = """
            \(categoryLine)\(statsLine)\(transcriptLine)\(transcriptEvidenceLine)
            Extract concise evidence bullets from this recording for a later parent-facing report.
            Keep only observations that identify repeated topics, repeated messages, attention signals, and evidence-based concerns.
            Use up to 8 bullet points.
            If audio and visual/on-screen cues disagree, prioritize audio meaning.
            When on-screen OCR or on-screen summary text is present, include a brief interpretation of what the screen showed.
            Do not invent creators, titles, apps, dialogue, or claims not present in the notes.
            Avoid generic category-only statements when more concrete message evidence exists.
            Never include raw timestamps (for example, 0:09).

            \(lines.joined(separator: "\n"))
            """
        } else {
            prompt = """
            \(categoryLine)\(transcriptLine)\(transcriptEvidenceLine)
            Extract concise evidence bullets from this recording chunk for a later parent-facing report.
            Keep only observations that identify repeated topics, repeated messages, attention signals, and evidence-based concerns.
            Use up to 6 bullet points.
            If audio and visual/on-screen cues disagree, prioritize audio meaning.
            When on-screen OCR or on-screen summary text is present, include a brief interpretation of what the screen showed.
            Do not invent creators, titles, apps, dialogue, or claims not present in the notes.
            Avoid generic category-only statements when more concrete message evidence exists.
            Never include raw timestamps (for example, 0:09).

            \(lines.joined(separator: "\n"))
            """
        }
        return try await respond(
            prompt: prompt,
            instructions: instructions(for: child)
        )
    }

    private func dailyTopicInstructions(for input: DailyInsightInput) -> String {
        let childContext: String?
        if let name = input.childName, let age = input.childAge {
            childContext = "The child is \(name), age \(age)."
        } else {
            childContext = nil
        }
        return analystFrameworkInstructions(childContext: childContext)
    }

    private func onScreenBriefInstructions() -> String {
        """
        You summarize on-screen content for parents from OCR text captured in child screen recordings.
        Use only the OCR text provided. Keep each summary to one short sentence.
        Do not include timestamps, bullet points, or prefixes like "on-screen:".
        """
    }

    private func parseNumberedOnScreenBriefs(_ text: String) -> [Int: String] {
        var result: [Int: String] = [:]
        let pattern = #"(?m)^\s*(\d+)\s*:\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match,
                  match.numberOfRanges >= 3,
                  let numberRange = Range(match.range(at: 1), in: text),
                  let summaryRange = Range(match.range(at: 2), in: text),
                  let number = Int(text[numberRange]) else { return }
            result[number] = String(text[summaryRange])
        }
        return result
    }

    private func analystFrameworkInstructions(childContext: String?) -> String {
        let childLine = childContext.map { "\($0)\n" } ?? ""
        return """
            You are an AI assistant that analyzes children's screen activity and helps parents understand what content their child was exposed to.
            Your goals are to identify: what the content was actually about, what messages were communicated, what themes appeared repeatedly, and what content appears to hold the child's attention.
            \(childLine)Focus on meaning, not labels.

            Content interpretation priority (highest to lowest):
            1. Spoken audio and transcript
            2. Creator speech captured in captions
            3. On-screen text and OCR text
            4. Visual content
            5. Category labels

            Spoken audio is the primary source of meaning.
            If audio and on-screen text suggest different meanings, prioritize the audio.

            Content type vs message:
            - "Educational", "Entertainment", and "Commercial" describe content type only.
            - These labels do not imply accuracy, safety, quality, age appropriateness, or positive influence.
            - Always evaluate the actual message being communicated.

            Analysis process:
            - Review all provided sessions/chunks together before final conclusions.
            - Identify recurring topics from spoken content first.
            - Extract key messages by asking what a child is most likely to remember.
            - Identify recurring patterns in topics, messages, format, speaking style, and themes.
            - Determine what appears to hold attention based on repeated exposure and viewing-time patterns.
            - Assess message quality as Positive, Neutral, Questionable, or Potentially Harmful.

            Attention language constraints:
            - Use cautious language: "may be interested in", "appears drawn to", "repeatedly viewed", "frequently exposed to".
            - Avoid certainty claims like "definitely likes", "enjoys", or "is passionate about" unless strongly evidence-backed.

            Safety and evidence constraints:
            - Consider dishonesty, risky behavior, manipulation, misinformation, aggression, profanity, and age-inappropriate themes.
            - Do not invent creators, titles, apps, dialogue, or facts not present in the notes.
            - Focus on repeated messages, not isolated moments.
            - Be factual and evidence-based; avoid speculation.
            """
    }

    private func sessionMetadataPrompt(
        statsString: String,
        overallCategory: String?,
        transcriptBrief: String?,
        transcriptEvidence: String?
    ) -> String {
        var lines: [String] = []
        if !statsString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(statsString.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let overallCategory,
           !overallCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Overall classification label: \(overallCategory)")
        }
        if let transcriptBrief {
            let trimmed = transcriptBrief.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                lines.append("Spoken content summary: \(trimmed)")
            }
        }
        if let transcriptEvidence {
            let trimmed = transcriptEvidence.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                lines.append("Transcript evidence:\n\(trimmed)")
            }
        }
        return lines.joined(separator: "\n")
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
            .replacingOccurrences(of: "on-screen:", with: "", options: .caseInsensitive)
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
            interval = Double(BroadcastConstants.classificationIntervalSeconds)
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
            if let onScreen = entry.onScreenBriefSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
               !onScreen.isEmpty {
                parts.append("on-screen: \(truncate(onScreen, limit: 120))")
            } else if let ocr = entry.onScreenTranscript?.trimmingCharacters(in: .whitespacesAndNewlines),
                      OnScreenTextSanitizer.isUsefulOnScreenContent(ocr) {
                parts.append("on-screen OCR: \(truncate(ocr, limit: 100))")
            } else if let prompt = entry.videoMatchedPrompt ?? entry.matchedPrompt {
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
