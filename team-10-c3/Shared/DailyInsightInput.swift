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
    let frameLines: [String]
    let transcriptNotes: String?
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
    func topicPromptBody() -> String {
        let lines = DailyContentDigestBuilder.allTopicLines(from: sessions)
        guard !lines.isEmpty else {
            return "No frame or transcript notes available for today."
        }
        return lines.joined(separator: "\n")
    }

    func promptBody() -> String {
        var lines: [String] = []
        lines.append("Date: \(dayLabel)")
        lines.append("Total session time (parent timer): \(DurationFormatting.verbose(seconds: totalSessionSeconds))")
        lines.append("Number of sessions: \(sessionCount)")

        if hasScreenTimeData {
            lines.append("App usage estimate: \(DurationFormatting.verbose(seconds: screenTimeAppTotalSeconds))")
            let appLines = topApps.prefix(8).map {
                "\($0.displayName): \(DurationFormatting.compact(seconds: $0.durationSeconds))"
            }
            if !appLines.isEmpty {
                lines.append("Top apps: \(appLines.joined(separator: ", "))")
            }
        }

        if !mergedCategoryBreakdown.isEmpty {
            let breakdown = mergedCategoryBreakdown.items
                .map { "\($0.name) \($0.percentage)%" }
                .joined(separator: ", ")
            lines.append("Category breakdown: \(breakdown)")
        }

        lines.append(topicPromptBody())
        return lines.joined(separator: "\n\n")
    }
}

#if DEBUG
extension DailyInsightInput {
    /// Prints a human-readable summary to the Xcode console (DEBUG builds only).
    func logToXcodeConsole(maxFrameLinesPerSession: Int = 6, maxTextChars: Int = 400) {
        func truncate(_ text: String, max: Int) -> String {
            guard text.count > max else { return text }
            return String(text.prefix(max)) + "…"
        }

        let childLine: String = {
            switch (childName, childAge) {
            case let (name?, age?): return "\(name), age \(age)"
            case let (name?, nil): return name
            case let (nil, age?): return "age \(age)"
            case (nil, nil): return "(unspecified)"
            }
        }()

        let breakdown = mergedCategoryBreakdown.items
            .map { "\($0.name): \($0.percentage)% (\($0.frameCount) frames)" }
            .joined(separator: "\n  ")

        let appLines = topApps.prefix(8).map {
            "\($0.displayName): \(DurationFormatting.compact(seconds: $0.durationSeconds))"
        }.joined(separator: "\n  ")

        let sessionBlocks = sessions.map { session in
            let frames = session.frameLines.prefix(maxFrameLinesPerSession).joined(separator: "\n      ")
            let moreFrames = session.frameLines.count > maxFrameLinesPerSession
                ? "\n      … +\(session.frameLines.count - maxFrameLinesPerSession) more frame lines"
                : ""
            return """
              Session \(session.index):
                Duration: \(DurationFormatting.verbose(seconds: session.durationSeconds))
                Category: \(session.dominantCategory)
                AI summary: \(truncate(session.aiSummary, max: maxTextChars))
                Frame lines (\(session.frameLines.count)):
                  \(frames.isEmpty ? "(none)" : frames)\(moreFrames)
                Transcript notes: \(session.transcriptNotes.map { truncate($0, max: maxTextChars) } ?? "(none)")
            """
        }.joined(separator: "\n")

        print("""

        ========== DailyInsightInput ==========
        Child: \(childLine)
        Date: \(dayLabel)
        Total session time: \(DurationFormatting.verbose(seconds: totalSessionSeconds))
        Session count: \(sessionCount)

        Merged category breakdown:
          \(breakdown.isEmpty ? "(empty)" : breakdown)

        Screen Time: \(hasScreenTimeData ? DurationFormatting.verbose(seconds: screenTimeAppTotalSeconds) : "(none)")
        Top apps:
          \(appLines.isEmpty ? "(none)" : appLines)

        Sessions:
        \(sessionBlocks.isEmpty ? "  (none)" : sessionBlocks)

        Prompt body preview:
        \(truncate(promptBody(), max: maxTextChars * 2))
        ========================================

        """)
    }
}
#endif
