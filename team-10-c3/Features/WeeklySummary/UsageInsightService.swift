//
//  UsageInsightService.swift
//  team-10-c3
//

import Foundation
import SwiftUI

struct UsageInsightReport: Equatable {
    let dateLabel: String
    let chartItems: [UsageChartItem]
    let aiSummary: String
    let offlineActivityTeaser: String
    let offlineActivity: String
    let needsAttention: Bool
    let weeklySuggestion: String?
}

struct UsageChartItem: Identifiable, Equatable {
    let id: String
    let name: String
    let value: Double
    let color: Color

    init(name: String, value: Double, color: Color) {
        self.id = name
        self.name = name
        self.value = value
        self.color = color
    }
}

@MainActor
struct UsageInsightService {
    let sessionRepository: SessionRepository
    let sessionAnalysisStore: SessionAnalysisStore
    let screenTimeService: ScreenTimeUsageProviding
    let familyControlsAuth: FamilyControlsAuthProviding

    func buildReport(
        childId: UUID,
        child: Child?,
        period: Period,
        referenceDate: Date = Date()
    ) async throws -> UsageInsightReport? {
        let calendar = Calendar.current
        let days = days(for: period, referenceDate: referenceDate, calendar: calendar)
        guard !days.isEmpty else { return nil }

        var totalSeconds = 0
        var mergedBreakdown = UsageCategoryBreakdown.empty
        var sessionResults: [(session: CompletedSessionReference, result: PipelineResult)] = []
        var latestOfflineActivity = "Let's take a 15-minute screen break together."
        var todaySnapshots: [SessionUsageSnapshot] = []
        var todaySessions: [CompletedSessionReference] = []
        var sessionsByDay: [(day: Date, sessions: [CompletedSessionReference], snapshots: [SessionUsageSnapshot])] = []

        for day in days {
            let sessions = try sessionRepository.completedSessions(for: childId, day: day)
            let snapshots = try sessionRepository.snapshots(for: childId, on: day)
            sessionsByDay.append((day: day, sessions: sessions, snapshots: snapshots))
            totalSeconds += snapshots.map(\.totalSeconds).reduce(0, +)

            if period == .daily, calendar.isDate(day, inSameDayAs: referenceDate) {
                todaySnapshots = snapshots
                todaySessions = sessions
            }
        }

        let allSessionIds = sessionsByDay
            .flatMap(\.sessions)
            .map(\.sessionId)
        let resultsById = sessionAnalysisStore.loadResults(sessionIds: allSessionIds)

        for dayData in sessionsByDay {
            for session in dayData.sessions {
                guard let result = resultsById[session.sessionId] else { continue }
                sessionResults.append((session, result))
                mergedBreakdown = mergedBreakdown.merged(with: result.categoryBreakdown)
            }
        }

        guard totalSeconds > 0 || !sessionResults.isEmpty else {
            return nil
        }

        if mergedBreakdown.isEmpty,
           let latest = sessionResults.max(by: { $0.session.stopAt < $1.session.stopAt }) {
            mergedBreakdown = latest.result.categoryBreakdown
        }

        if let latest = sessionResults.max(by: { $0.session.stopAt < $1.session.stopAt }) {
            latestOfflineActivity = latest.result.offlineActivity
        }

        let chartItems = chartItems(from: mergedBreakdown)
        let dateLabel = formattedDateLabel(
            period: period,
            days: days,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let aiSummary: String
        let weeklySuggestion: String?
        switch period {
        case .daily:
            aiSummary = await buildDailySummary(
                child: child,
                dayLabel: dateLabel,
                totalSeconds: totalSeconds,
                mergedBreakdown: mergedBreakdown,
                sessionResults: sessionResults,
                snapshots: todaySnapshots,
                sessions: todaySessions,
                childId: childId
            )
            weeklySuggestion = nil
        case .weekly:
            aiSummary = InsightProseBuilder.weeklySummary(
                totalSeconds: totalSeconds,
                breakdown: mergedBreakdown
            )
            weeklySuggestion = InsightProseBuilder.weeklySuggestion()
        }

        return UsageInsightReport(
            dateLabel: dateLabel,
            chartItems: chartItems,
            aiSummary: aiSummary,
            offlineActivityTeaser: InsightProseBuilder.offlineActivityTeaser,
            offlineActivity: latestOfflineActivity,
            needsAttention: false,
            weeklySuggestion: weeklySuggestion
        )
    }

    private func buildDailySummary(
        child: Child?,
        dayLabel: String,
        totalSeconds: Int,
        mergedBreakdown: UsageCategoryBreakdown,
        sessionResults: [(session: CompletedSessionReference, result: PipelineResult)],
        snapshots: [SessionUsageSnapshot],
        sessions: [CompletedSessionReference],
        childId: UUID
    ) async -> String {
        let startedAt = ContinuousClock.now
        var lastCheckpoint = startedAt
        func logTiming(_ label: String) {
            let now = ContinuousClock.now
            let delta = lastCheckpoint.duration(to: now)
            let total = startedAt.duration(to: now)
            print("⏱️ Daily insight timing: \(label) +\(delta) total \(total)")
            lastCheckpoint = now
        }

        let topApps = await fetchTopApps(childId: childId, sessions: sessions, snapshots: snapshots)
        logTiming("fetchTopApps")

        let input = DailyInsightInput.make(
            child: child,
            dayLabel: dayLabel,
            totalSessionSeconds: totalSeconds,
            sessionCount: max(sessions.count, sessionResults.count),
            mergedCategoryBreakdown: mergedBreakdown,
            sessionResults: sessionResults,
            snapshots: snapshots,
            topApps: topApps
        )
        logTiming("buildDailyInput")
        #if DEBUG
        input.logToXcodeConsole()
        #endif

        let dayKey = Self.dayCacheKey(from: sessions, fallbackLabel: dayLabel)
        let sessionSignature = Self.sessionSignature(from: sessionResults)
        if let cached = sessionAnalysisStore.dailyInsightCache(
            childId: childId,
            dayKey: dayKey,
            sessionSignature: sessionSignature
        ) {
            logTiming("dailyCacheHit")
            return cached
        }

        let summarizer = LLMSummarizer()
        do {
            let summary = try await summarizer.summarizeDailyInsight(input: input)
            logTiming("dailyLLM")
            if !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sessionAnalysisStore.saveDailyInsightCache(
                    childId: childId,
                    dayKey: dayKey,
                    sessionSignature: sessionSignature,
                    summary: summary
                )
                logTiming("saveDailyCache")
                return summary
            }
        } catch {
            // Fall through to template summary.
        }

        let fallback = InsightProseBuilder.dailySummary(
            childName: child?.name,
            totalSeconds: totalSeconds,
            breakdown: mergedBreakdown,
            sessions: input.sessions
        )
        logTiming("fallbackSummary")
        return fallback
    }

    private func fetchTopApps(
        childId: UUID,
        sessions: [CompletedSessionReference],
        snapshots: [SessionUsageSnapshot]
    ) async -> [AppUsageRow] {
        guard familyControlsAuth.canRecordSessionUsage else { return [] }

        let windows: [SessionWindow]
        if !sessions.isEmpty {
            windows = sessions.map { SessionWindow(startAt: $0.startAt, stopAt: $0.stopAt) }
        } else {
            windows = snapshots.map { SessionWindow(startAt: $0.startAt, stopAt: $0.stopAt) }
        }
        guard !windows.isEmpty else { return [] }

        do {
            let result = try await screenTimeService.fetchHourlyUsageForSessions(
                childId: childId,
                sessions: windows
            )
            return Array(result.apps.prefix(8))
        } catch {
            return []
        }
    }

    private func days(for period: Period, referenceDate: Date, calendar: Calendar) -> [Date] {
        switch period {
        case .daily:
            return [calendar.startOfDay(for: referenceDate)]
        case .weekly:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
                return [calendar.startOfDay(for: referenceDate)]
            }
            var days: [Date] = []
            var cursor = interval.start
            while cursor < interval.end {
                days.append(calendar.startOfDay(for: cursor))
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            return days
        }
    }

    private func formattedDateLabel(
        period: Period,
        days: [Date],
        referenceDate: Date,
        calendar: Calendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"

        switch period {
        case .daily:
            return formatter.string(from: referenceDate)
        case .weekly:
            guard let first = days.first, let last = days.last else {
                return formatter.string(from: referenceDate)
            }
            let endDay = calendar.date(byAdding: .day, value: -1, to: last) ?? last
            let startText = formatter.string(from: first)
            let endText = formatter.string(from: endDay)
            return "\(startText) – \(endText)"
        }
    }

    private func chartItems(from breakdown: UsageCategoryBreakdown) -> [UsageChartItem] {
        breakdown.items.map { item in
            let category = UsageInsightChartCategory(rawValue: item.name)
                ?? UsageInsightChartCategory.fromPipelineLabel(item.name)
            return UsageChartItem(
                name: item.name,
                value: Double(item.percentage),
                color: category.color
            )
        }
    }

    private static func dayCacheKey(from sessions: [CompletedSessionReference], fallbackLabel: String) -> String {
        guard let latest = sessions.max(by: { $0.stopAt < $1.stopAt }) else {
            return fallbackLabel
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: latest.stopAt)
    }

    private static func sessionSignature(
        from sessionResults: [(session: CompletedSessionReference, result: PipelineResult)]
    ) -> String {
        sessionResults
            .map { "\($0.session.sessionId.uuidString):\($0.session.stopAt.timeIntervalSince1970)" }
            .sorted()
            .joined(separator: "|")
    }
}
