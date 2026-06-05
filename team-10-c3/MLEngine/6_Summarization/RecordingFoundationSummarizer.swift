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
                Highlight the main apps used, the general themes of the content watched (e.g., educational, gaming, entertainment), and any specific creators or channels.
                If session statistics (like duration, percentages, and creators' watch time) are provided, incorporate them naturally into the summary.
                Use only the provided segment notes and session insights. Do not invent details.
                Write clear, factual prose in 2-4 sentences for a full recording, or 1 sentence for a chunk of segments.
                """
        } else {
            return """
                You are a parental monitoring assistant analyzing a child's screen recording session.
                Summarize the activity clearly and objectively for a parent. 
                Highlight the main apps used, the general themes of the content watched (e.g., educational, gaming, entertainment), and any specific creators or channels.
                If session statistics (like duration, percentages, and creators' watch time) are provided, incorporate them naturally into the summary.
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

        let prompt = """
        Write one daily overview for a parent based on today's data below.
        Use 2-4 clear sentences. Mention total screen time and the main content themes (educational, entertainment, commercial).
        When spoken content is provided, ground the overview in those excerpts alongside each session AI summary.
        If how-it-sounded notes are provided, mention audio patterns only when supported by the data.
        If concern signals are listed, note them briefly. Use only the facts provided — do not invent apps, creators, dialogue, or durations.

        \(input.promptBody())
        """

        return try await respond(
            prompt: prompt,
            instructions: dailyInstructions(for: input)
        )
    }

    public func summarizeRecording(
        timeline: [FrameClassificationSummary],
        overallCategory: String?,
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
        isFinalPass: Bool,
        child: Child?
    ) async throws -> String {
        let categoryLine = overallCategory.map { "Overall classification: \($0)\n" } ?? ""
        let statsLine = isFinalPass ? "\n\(statsString)\n" : ""
        let prompt: String
        if isFinalPass {
            prompt = """
            \(categoryLine)\(statsLine)Summarize what the user watched in this screen recording based on these time-stamped segment notes and statistics. Make sure to naturally mention the duration, percentages, and creators:

            \(lines.joined(separator: "\n"))
            """
        } else {
            prompt = """
            \(categoryLine)Summarize this portion of a screen recording in 1-2 sentences:

            \(lines.joined(separator: "\n"))
            """
        }
        return try await respond(prompt: prompt, child: child)
    }

    private func dailyInstructions(for input: DailyInsightInput) -> String {
        if let name = input.childName, let age = input.childAge {
            return """
                You are a parental monitoring assistant writing a daily screen-time overview for a parent of \(name), age \(age).
                Synthesize today's session summaries, spoken content excerpts, category mix, and screen time into one cohesive paragraph.
                Use \(name) when it reads naturally. Be objective and reassuring. Do not invent details or dialogue.
                Write 2-4 sentences only.
                """
        }
        return """
            You are a parental monitoring assistant writing a daily screen-time overview for a parent.
            Synthesize today's session summaries, spoken content excerpts, category mix, and screen time into one cohesive paragraph.
            Be objective and reassuring. Do not invent details or dialogue. Write 2-4 sentences only.
            """
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
        var creatorCounts: [String: Int] = [:]
        
        for item in timeline {
            categoryCounts[item.label, default: 0] += 1
            if let creator = item.creatorHandle {
                creatorCounts[creator, default: 0] += 1
            }
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
        
        if !creatorCounts.isEmpty {
            let sortedCreators = creatorCounts.sorted { $0.value > $1.value }
            statsString += "- Creators watched:\n"
            for (creator, count) in sortedCreators {
                let duration = Double(count) * interval
                let mins = Int(duration) / 60
                let secs = Int(duration) % 60
                let timeStr = mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
                statsString += "  * \(creator): \(timeStr)\n"
            }
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
