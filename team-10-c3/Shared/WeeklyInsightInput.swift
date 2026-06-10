//
//  WeeklyInsightInput.swift
//  team-10-c3
//

import Foundation

struct WeeklyInsightOutput: Equatable, Sendable {
    let shortSummary: String
    let detailSummary: String
    let weeklySuggestion: String
    let followUpOptions: [String]

    static let defaultFollowUpOptions = [
        "Opened up and talked",
        "Enjoyed it, not much talking",
        "Led to a longer conversation",
        "Didn't want to",
    ]

    /// Fixes model output that was stored unparsed (headers/markdown leaked into UI fields).
    func repaired() -> WeeklyInsightOutput {
        WeeklyInsightParser.repair(self)
    }
}

struct WeeklyInsightInput: Sendable {
    let childName: String?
    let childAge: Int?
    let weekLabel: String
    let totalSessionSeconds: Int
    let sessionCount: Int
    let mergedCategoryBreakdown: UsageCategoryBreakdown
    let sessions: [DailySessionInsight]

    static func make(
        child: Child?,
        weekLabel: String,
        totalSessionSeconds: Int,
        sessionResults: [(session: CompletedSessionReference, result: PipelineResult)],
        snapshots: [SessionUsageSnapshot],
        mergedCategoryBreakdown: UsageCategoryBreakdown
    ) -> WeeklyInsightInput {
        let sessionInsights = sessionResults.enumerated().map { offset, entry in
            let brief = entry.result.sessionTranscriptBriefSummary
                ?? entry.result.sessionTranscriptDigest
            let aiSummary = entry.result.summary
            let frameLines: [String]
            if TranscriptSanitizer.isMeaningful(aiSummary) {
                frameLines = []
            } else {
                frameLines = DailyContentDigestBuilder.sessionFrameLines(screens: entry.result.screens)
            }

            return DailySessionInsight(
                index: offset + 1,
                durationSeconds: snapshotDuration(for: entry.session, snapshots: snapshots),
                dominantCategory: entry.result.category,
                aiSummary: aiSummary,
                frameLines: frameLines,
                transcriptNotes: DailyContentDigestBuilder.sessionTranscriptNotes(
                    digest: nil,
                    brief: brief
                )
            )
        }

        return WeeklyInsightInput(
            childName: child?.name,
            childAge: child?.currentAge,
            weekLabel: weekLabel,
            totalSessionSeconds: totalSessionSeconds,
            sessionCount: max(sessionResults.count, sessionInsights.count),
            mergedCategoryBreakdown: mergedCategoryBreakdown,
            sessions: sessionInsights
        )
    }

    private static func snapshotDuration(
        for session: CompletedSessionReference,
        snapshots: [SessionUsageSnapshot]
    ) -> Int {
        let tolerance: TimeInterval = 5
        let match = snapshots.first {
            abs($0.startAt.timeIntervalSince(session.startAt)) < tolerance
                && abs($0.stopAt.timeIntervalSince(session.stopAt)) < tolerance
        }
        return match?.totalSeconds ?? 0
    }

    func metadataPrompt() -> String {
        var lines: [String] = []
        if let childName {
            if let childAge {
                lines.append("Child: \(childName), age \(childAge)")
            } else {
                lines.append("Child: \(childName)")
            }
        }
        lines.append("Week: \(weekLabel)")
        lines.append("Total session time: \(DurationFormatting.verbose(seconds: totalSessionSeconds))")
        lines.append("Number of sessions: \(sessionCount)")
        if !mergedCategoryBreakdown.isEmpty {
            let breakdown = mergedCategoryBreakdown.items
                .map { "\($0.name) \($0.percentage)%" }
                .joined(separator: ", ")
            lines.append("Category breakdown: \(breakdown)")
        }
        return lines.joined(separator: "\n")
    }

    func topicPromptBody() -> String {
        let lines = DailyContentDigestBuilder.allTopicLines(from: sessions)
        guard !lines.isEmpty else {
            return "No frame or transcript notes available for this week."
        }
        return lines.joined(separator: "\n")
    }
}

enum WeeklyInsightParser {
    static func parse(_ text: String) -> WeeklyInsightOutput? {
        let normalized = InsightSummaryParser.normalize(text)
        guard !normalized.isEmpty else { return nil }

        let blocks = InsightSummaryParser.extractBlocks(from: normalized)
        guard let short = blocks["SHORT_SUMMARY"] ?? blocks["SUMMARY"],
              !short.isEmpty,
              let suggestion = blocks["SUGGESTION"],
              !suggestion.isEmpty else {
            return nil
        }

        let detail = blocks["DETAIL"] ?? short
        let followUpBlock = blocks["FOLLOWUP_OPTIONS"] ?? blocks["FOLLOW_UP_OPTIONS"]
        let followUps = sanitizeFollowUps(parseBullets(followUpBlock))

        return WeeklyInsightOutput(
            shortSummary: InsightSummaryParser.cleanProse(short),
            detailSummary: InsightSummaryParser.cleanProse(detail),
            weeklySuggestion: InsightSummaryParser.cleanProse(suggestion),
            followUpOptions: followUps.isEmpty ? WeeklyInsightOutput.defaultFollowUpOptions : followUps
        )
    }

    static func repair(_ output: WeeklyInsightOutput) -> WeeklyInsightOutput {
        let summaryNeedsRepair = containsSectionMarkers(output.shortSummary)
            || containsSectionMarkers(output.detailSummary)
        let suggestionNeedsRepair = containsSectionMarkers(output.weeklySuggestion)
        let followUpsNeedRepair = output.followUpOptions.contains(where: isTemplatePlaceholder)

        guard summaryNeedsRepair || suggestionNeedsRepair || followUpsNeedRepair else {
            return output
        }

        let combined = [output.shortSummary, output.detailSummary, output.weeklySuggestion]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        if let parsed = parse(combined) {
            return parsed
        }

        if let summaryPair = InsightSummaryParser.parse(combined) {
            return WeeklyInsightOutput(
                shortSummary: summaryPair.shortSummary,
                detailSummary: summaryPair.detailSummary,
                weeklySuggestion: stripTrailingSections(from: output.weeklySuggestion),
                followUpOptions: sanitizeFollowUps(output.followUpOptions)
            )
        }

        return WeeklyInsightOutput(
            shortSummary: stripTrailingSections(from: output.shortSummary),
            detailSummary: output.detailSummary.isEmpty
                ? stripTrailingSections(from: output.shortSummary)
                : output.detailSummary,
            weeklySuggestion: stripTrailingSections(from: output.weeklySuggestion),
            followUpOptions: sanitizeFollowUps(output.followUpOptions)
        )
    }

    private static func parseBullets(_ block: String?) -> [String] {
        guard let block else { return [] }
        return block
            .split(separator: "\n")
            .map { line in
                var trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                while trimmed.first == "-" || trimmed.first == "•" || trimmed.first == "*" {
                    trimmed.removeFirst()
                    trimmed = trimmed.trimmingCharacters(in: .whitespaces)
                }
                return trimmed
            }
            .filter { !$0.isEmpty }
    }

    private static func sanitizeFollowUps(_ options: [String]) -> [String] {
        let cleaned = options
            .map { InsightSummaryParser.cleanProse($0) }
            .filter { !$0.isEmpty }
            .filter { !isTemplatePlaceholder($0) }
        return Array(cleaned.prefix(6))
    }

    private static func isTemplatePlaceholder(_ value: String) -> Bool {
        let lower = value.lowercased()
        if lower.contains("<") && lower.contains(">") { return true }
        if lower.contains("short option for") { return true }
        if lower == "option 2" || lower == "option 3" || lower == "option 4" { return true }
        return false
    }

    private static func containsSectionMarkers(_ text: String) -> Bool {
        let upper = text.uppercased()
        return upper.contains("SUGGESTION:") || upper.contains("FOLLOWUP_OPTIONS:")
            || upper.contains("FOLLOW_UP_OPTIONS:") || upper.contains("DETAIL:")
            || text.contains("**")
    }

    private static func stripTrailingSections(from text: String) -> String {
        let normalized = InsightSummaryParser.normalize(text)
        if let short = InsightSummaryParser.extractBlocks(from: normalized)["SHORT_SUMMARY"]
            ?? InsightSummaryParser.extractBlocks(from: normalized)["SUMMARY"] {
            return InsightSummaryParser.cleanProse(short)
        }

        var result = normalized
        for marker in [
            "\nDETAIL:", "\nSUGGESTION:", "\nFOLLOWUP_OPTIONS:", "\nFOLLOW_UP_OPTIONS:",
        ] {
            if let range = result.range(of: marker, options: [.caseInsensitive]) {
                result = String(result[..<range.lowerBound])
            }
        }
        return InsightSummaryParser.cleanProse(result)
    }
}

enum WeeklyInsightFormatting {
    static func weekKey(referenceDate: Date, calendar: Calendar = .current) -> String {
        let week = calendar.component(.weekOfYear, from: referenceDate)
        let year = calendar.component(.yearForWeekOfYear, from: referenceDate)
        return String(format: "%d-W%02d", year, week)
    }
}
