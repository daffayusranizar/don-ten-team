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
        return PromptLibrary.Summarization.analystFrameworkInstructions(childContext: childContext)
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

    func summarizeDailyInsight(input: DailyInsightInput) async throws -> InsightSummaryPair {
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

    func summarizeWeeklyInsight(input: WeeklyInsightInput) async throws -> WeeklyInsightOutput {
        guard #available(iOS 26, *) else {
            throw SummarizerError.requiresIOS26
        }
        guard availability() == .available else {
            throw SummarizerError.modelUnavailable(availability().statusMessage ?? "Model unavailable.")
        }

        guard input.totalSessionSeconds > 0 || !input.sessions.isEmpty else {
            throw SummarizerError.emptyInput
        }

        return try await summarizeWeeklyInsightOnDevice(input: input)
    }

    @available(iOS 26, *)
    private func summarizeWeeklyInsightOnDevice(input: WeeklyInsightInput) async throws -> WeeklyInsightOutput {
        // One model response → summary, suggestion, and follow-up options stay in sync.
        let childContext: String? = {
            switch (input.childName, input.childAge) {
            case let (name?, age?):
                return "The child is \(name), age \(age)."
            case let (name?, nil):
                return "The child is \(name)."
            default:
                return nil
            }
        }()
        let instructions = PromptLibrary.Summarization.analystFrameworkInstructions(
            childContext: childContext
        )
        let prompt = PromptLibrary.Summarization.weeklyInsightPrompt(
            metadata: input.metadataPrompt(),
            topicBody: input.topicPromptBody()
        )
        let response = try await respond(
            prompt: prompt,
            instructions: instructions
        )
        if let parsed = WeeklyInsightParser.parse(response) {
            return parsed.repaired()
        }

        let fallbackShort = InsightProseBuilder.weeklySummary(
            totalSeconds: input.totalSessionSeconds,
            breakdown: input.mergedCategoryBreakdown
        )

        return WeeklyInsightOutput(
            shortSummary: fallbackShort,
            detailSummary: fallbackShort,
            weeklySuggestion: InsightProseBuilder.weeklySuggestion(),
            followUpOptions: WeeklyInsightOutput.defaultFollowUpOptions
        )
    }

    @available(iOS 26, *)
    private func summarizeDailyTopics(input: DailyInsightInput) async throws -> InsightSummaryPair {
        let topicLines = DailyContentDigestBuilder.allTopicLines(from: input.sessions)
        guard !topicLines.isEmpty else {
            return InsightSummaryPair(shortSummary: "", detailSummary: "")
        }

        let chunks = chunkLines(topicLines, maxCharacters: 2_800)
        var evidenceNotes: [String] = []

        for chunk in chunks {
            let summary = try await summarizeDailyTopicChunk(chunk, input: input)
            if !summary.isEmpty {
                evidenceNotes.append(summary)
            }
        }

        guard !evidenceNotes.isEmpty else {
            return InsightSummaryPair(shortSummary: "", detailSummary: "")
        }

        let mergePrompt = PromptLibrary.Summarization.dailyTopicMergePrompt(
            metadata: dailyMetadataPrompt(for: input),
            evidenceNotes: evidenceNotes
        )
        let merged = try await respond(
            prompt: mergePrompt,
            instructions: dailyTopicInstructions(for: input)
        )
        let sanitized = sanitizeDailyReport(merged)
        return InsightSummaryParser.parse(sanitized)
            ?? InsightSummaryPair.fromLegacySingleSummary(sanitized)
    }

    @available(iOS 26, *)
    private func summarizeDailyTopicChunk(
        _ lines: [String],
        input: DailyInsightInput
    ) async throws -> String {
        let prompt = PromptLibrary.Summarization.dailyTopicChunkPrompt(
            metadata: dailyMetadataPrompt(for: input),
            lines: lines
        )
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
            let prompt = PromptLibrary.Summarization.onScreenBriefPrompt(chunk: chunk)
            do {
                let response = try await respond(
                    prompt: prompt,
                    instructions: PromptLibrary.Summarization.onScreenBriefInstructions()
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
        fullTrackTranscript: String? = nil,
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
        var supportingEvidenceNotes: [String] = []

        for chunk in chunks {
            let summary = try await summarizeChunk(
                chunk,
                overallCategory: overallCategory,
                child: child
            )
            if !summary.isEmpty {
                supportingEvidenceNotes.append(summary)
            }
        }

        let fullTrackEvidenceNotes = try await summarizeFullTrackEvidenceNotes(
            fullTrackTranscript: fullTrackTranscript,
            overallCategory: overallCategory,
            statsString: statsString,
            child: child
        )

        guard !supportingEvidenceNotes.isEmpty || !fullTrackEvidenceNotes.isEmpty else {
            throw SummarizerError.emptyInput
        }

        let sessionMetadata = PromptLibrary.Summarization.sessionMetadataPrompt(
            statsString: statsString,
            overallCategory: overallCategory,
            transcriptBrief: transcriptBrief,
            transcriptEvidence: transcriptEvidence
        )
        let merged = try await respond(
            prompt: PromptLibrary.Summarization.parentFacingSessionSummaryPrompt(
                sessionMetadata: sessionMetadata,
                fullTrackNotes: fullTrackEvidenceNotes,
                evidenceNotes: supportingEvidenceNotes
            ),
            instructions: instructions(for: child)
        )
        return sanitizeDailyReport(merged)
    }

    @available(iOS 26, *)
    private func summarizeChunk(
        _ lines: [String],
        overallCategory: String?,
        child: Child?
    ) async throws -> String {
        let categoryLine = overallCategory.map { "Overall classification: \($0)\n" } ?? ""
        let prompt = PromptLibrary.Summarization.recordingChunkEvidencePrompt(
            categoryLine: categoryLine,
            lines: lines
        )
        return try await respond(
            prompt: prompt,
            instructions: instructions(for: child)
        )
    }

    @available(iOS 26, *)
    private func summarizeFullTrackEvidenceNotes(
        fullTrackTranscript: String?,
        overallCategory: String?,
        statsString: String,
        child: Child?
    ) async throws -> [String] {
        guard let fullTrackTranscript else { return [] }
        let cleaned = TranscriptSanitizer.sanitize(fullTrackTranscript)
        guard TranscriptSanitizer.isMeaningful(cleaned) else { return [] }

        let chunks = fullTrackTranscriptChunks(cleaned, maxCharacters: 2_800)
        guard !chunks.isEmpty else { return [] }

        let categoryLine = overallCategory.map { "Overall classification: \($0)\n" } ?? ""
        var notes: [String] = []
        for chunk in chunks {
            let prompt = PromptLibrary.Summarization.fullTrackEvidencePrompt(
                categoryLine: categoryLine,
                statsString: statsString,
                chunk: chunk
            )
            let response = try await respond(
                prompt: prompt,
                instructions: instructions(for: child)
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            if !response.isEmpty {
                notes.append(response)
            }
        }
        return notes
    }

    private func dailyTopicInstructions(for input: DailyInsightInput) -> String {
        let childContext: String?
        if let name = input.childName, let age = input.childAge {
            childContext = "The child is \(name), age \(age)."
        } else {
            childContext = nil
        }
        return PromptLibrary.Summarization.analystFrameworkInstructions(childContext: childContext)
    }

    private func dailyMetadataPrompt(for input: DailyInsightInput) -> String {
        let categoryBreakdown: String?
        if input.mergedCategoryBreakdown.isEmpty {
            categoryBreakdown = nil
        } else {
            categoryBreakdown = input.mergedCategoryBreakdown.items
                .map { "\($0.name) \($0.percentage)%" }
                .joined(separator: ", ")
        }

        let appUsageEstimate: String?
        let topApps: String?
        if input.hasScreenTimeData {
            appUsageEstimate = DurationFormatting.verbose(seconds: input.screenTimeAppTotalSeconds)
            topApps = input.topApps.prefix(3).map {
                "\($0.displayName): \(DurationFormatting.compact(seconds: $0.durationSeconds))"
            }.joined(separator: ", ")
        } else {
            appUsageEstimate = nil
            topApps = nil
        }

        return PromptLibrary.Summarization.dailyMetadataPrompt(
            dayLabel: input.dayLabel,
            childAgeText: input.childAge.map { String($0) } ?? "unknown",
            totalSessionTime: DurationFormatting.verbose(seconds: input.totalSessionSeconds),
            sessionCount: input.sessionCount,
            categoryBreakdown: categoryBreakdown,
            appUsageEstimate: appUsageEstimate,
            topApps: topApps
        )
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

    private func sanitizeDailyReport(_ text: String) -> String {
        let patterns = [
            #"\b\d{1,2}:\d{2}\b"#,
            #"\b\d{1,2}\s*[—-]\s*"#
        ]
        let forbiddenSentencePatterns = [
            #"[^.!?]*screen\s*[- ]?\s*by\s*[- ]?\s*screen\s+breakdown[^.!?]*[.!?]?"#,
            #"[^.!?]*(open|view|check|see)\s+[^.!?]*breakdown[^.!?]*[.!?]?"#
        ]

        var cleaned = text
        for pattern in patterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        for pattern in forbiddenSentencePatterns {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        cleaned = cleaned
            .replacingOccurrences(of: "visual:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "spoken:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "on-screen:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "audio:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+([.,!?])"#, with: "$1", options: .regularExpression)
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

    private func fullTrackTranscriptChunks(_ text: String, maxCharacters: Int) -> [String] {
        guard maxCharacters > 0 else { return [] }
        let words = text.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return [] }

        var chunks: [String] = []
        var current = ""
        for word in words {
            let token = String(word)
            let candidateLength = current.isEmpty ? token.count : current.count + 1 + token.count
            if candidateLength > maxCharacters, !current.isEmpty {
                chunks.append(current)
                current = token
            } else if current.isEmpty {
                current = token
            } else {
                current += " " + token
            }
        }

        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
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
