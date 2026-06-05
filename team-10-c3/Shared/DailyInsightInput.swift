//
//  DailyInsightInput.swift
//  team-10-c3
//

import Foundation

struct DailySessionInsight: Sendable {
    let index: Int
    let durationSeconds: Int
    let dominantCategory: String
    let aiSummary: String
    let transcriptBriefSummary: String?
}

struct DailyInsightInput: Sendable {
    let childName: String?
    let childAge: Int?
    let dayLabel: String
    let totalSessionSeconds: Int
    let sessionCount: Int
    let mergedCategoryBreakdown: UsageCategoryBreakdown
    let sessions: [DailySessionInsight]
    let topApps: [AppUsageRow]
    let screenTimeAppTotalSeconds: Int
    let hasScreenTimeData: Bool

    static func make(
        child: Child?,
        dayLabel: String,
        totalSessionSeconds: Int,
        sessionCount: Int,
        mergedCategoryBreakdown: UsageCategoryBreakdown,
        sessionResults: [(session: CompletedSessionReference, result: PipelineResult)],
        snapshots: [SessionUsageSnapshot],
        topApps: [AppUsageRow]
    ) -> DailyInsightInput {
        let sessionInsights = sessionResults.enumerated().map { offset, entry in
            DailySessionInsight(
                index: offset + 1,
                durationSeconds: snapshotDuration(for: entry.session, snapshots: snapshots),
                dominantCategory: entry.result.category,
                aiSummary: entry.result.summary,
                transcriptBriefSummary: entry.result.sessionTranscriptBriefSummary
                    ?? TranscriptDigestBuilder.buildBriefSummary(
                        fullTrackText: nil,
                        digest: TranscriptDigestBuilder.resolvedDigest(
                            stored: entry.result.sessionTranscriptDigest,
                            screens: entry.result.screens
                        )
                    )
            )
        }

        let screenTimeTotal = topApps.map(\.durationSeconds).reduce(0, +)

        return DailyInsightInput(
            childName: child?.name,
            childAge: child?.currentAge,
            dayLabel: dayLabel,
            totalSessionSeconds: totalSessionSeconds,
            sessionCount: sessionCount,
            mergedCategoryBreakdown: mergedCategoryBreakdown,
            sessions: sessionInsights,
            topApps: topApps,
            screenTimeAppTotalSeconds: screenTimeTotal,
            hasScreenTimeData: !topApps.isEmpty
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
}

extension DailyInsightInput {
    func promptBody() -> String {
        var lines: [String] = []
        lines.append("Date: \(dayLabel)")
        lines.append("Total session time (parent timer): \(DurationFormatting.verbose(seconds: totalSessionSeconds))")
        lines.append("Number of sessions: \(sessionCount)")

        if hasScreenTimeData {
            lines.append("Screen Time app estimate: \(DurationFormatting.verbose(seconds: screenTimeAppTotalSeconds))")
            let appLines = topApps.prefix(8).map {
                "\($0.displayName): \(DurationFormatting.compact(seconds: $0.durationSeconds))"
            }
            if !appLines.isEmpty {
                lines.append("Top apps: \(appLines.joined(separator: ", "))")
            }
        } else {
            lines.append("Screen Time app estimate: not available (permissions or no data)")
        }

        if !mergedCategoryBreakdown.isEmpty {
            let breakdown = mergedCategoryBreakdown.items
                .map { "\($0.name) \($0.percentage)%" }
                .joined(separator: ", ")
            lines.append("Category breakdown: \(breakdown)")
        }

        for session in sessions {
            var block = """
            Session \(session.index) (\(DurationFormatting.compact(seconds: session.durationSeconds)), \(session.dominantCategory)):
            AI summary: \(session.aiSummary)
            """
            if let brief = session.transcriptBriefSummary, TranscriptSanitizer.isMeaningful(brief) {
                block += "\nSpoken content summary: \(brief)"
            }
            lines.append(block)
        }

        return lines.joined(separator: "\n\n")
    }
}
