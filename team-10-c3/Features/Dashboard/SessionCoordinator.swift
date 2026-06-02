//
//  SessionCoordinator.swift
//  team-10-c3
//

import Foundation
import Observation
import SwiftUI

struct DashboardSessionData: Identifiable, Equatable {
    let id = UUID()
    let type: String
    let duration: Int
    let colorName: String

    var color: Color {
        switch colorName {
        case "sky": return .decorativeSkyBlue
        case "yellow": return .decorativeSunnyYellow
        case "mint": return .decorativeMintGreen
        case "coral": return .decorativeCoralPink
        default: return .decorativeSkyBlue
        }
    }
}

@Observable
@MainActor
final class SessionCoordinator {
    private let sessionRepository: SessionRepository
    private let screenTimeService: ScreenTimeUsageProviding

    var isSessionActive = false
    var isSessionComplete = false
    var sessionStartAt: Date?
    var plannedEndAt: Date?
    var remainingSeconds = 0
    var durationMinutes = 30
    var loadError: String?
    var summaryPeriodTitle = "Today's Session"
    var summaryChartSessions: [DashboardSessionData] = []
    var summaryTopApps: [AppUsageRow] = []
    var hasSummaryData = false
    var hasTodayActivity = false
    var currentDayTotalSeconds = 0
    var latestBannerTotalSeconds = 0
    var latestSessionLimitSeconds = 90 * 60
    var isRefreshingScreenTime = false
    var latestTotalSeconds = 0
    var usageReportRequest: (childId: UUID, startAt: Date, stopAt: Date)?

    private var timerTask: Task<Void, Never>?
    private var activeChildId: UUID?

    let durationOptions = [15, 30, 45, 60]

    init(
        sessionRepository: SessionRepository,
        screenTimeService: ScreenTimeUsageProviding
    ) {
        self.sessionRepository = sessionRepository
        self.screenTimeService = screenTimeService
    }

    var formattedRemainingTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedElapsedOrTotal: String {
        formatDuration(seconds: isSessionActive ? elapsedSeconds : latestTotalSeconds)
    }

    var formattedCurrentDayTotal: String {
        formatDuration(seconds: currentDayTotalSeconds)
    }

    var formattedLatestBannerTotal: String {
        formatDuration(seconds: latestBannerTotalSeconds)
    }

    var currentDayProgress: Double {
        let limit = max(1, durationMinutes * 60)
        return min(1, Double(currentDayTotalSeconds) / Double(limit))
    }

    var latestBannerProgress: Double {
        let limit = max(1, latestSessionLimitSeconds)
        return min(1, Double(latestBannerTotalSeconds) / Double(limit))
    }

    var formattedTimeLimit: String {
        formatDuration(seconds: durationMinutes * 60)
    }

    private var elapsedSeconds: Int {
        guard let sessionStartAt else { return 0 }
        return max(0, Int(Date().timeIntervalSince(sessionStartAt)))
    }

    var sessionProgress: Double {
        let limit = max(1, durationMinutes * 60)
        if isSessionActive {
            return min(1, Double(elapsedSeconds) / Double(limit))
        }
        guard latestTotalSeconds > 0 else { return 0 }
        return min(1, Double(latestTotalSeconds) / Double(limit))
    }

    func refresh(for child: Child?) {
        guard let child else {
            resetDisplayState()
            return
        }
        Task { await performRefresh(for: child) }
    }

    private func performRefresh(for child: Child) async {
        do {
            if let active = try sessionRepository.activeSession(for: child.id) {
                applyActiveSession(childId: child.id, startedAt: active.startedAt)
            } else {
                isSessionActive = false
                activeChildId = nil
                timerTask?.cancel()
            }

            await refreshScreenTimeFromAPI(for: child.id)
            loadSummaryActivity(for: child.id)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func startSession(child: Child, durationMinutes: Int) {
        guard !isSessionActive else { return }

        self.durationMinutes = durationMinutes
        let startAt = Date()
        let plannedEnd = startAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
        plannedEndAt = plannedEnd

        do {
            _ = try sessionRepository.recordMarker(childId: child.id, type: .start, timestamp: startAt)
            try screenTimeService.startMonitoring(
                childId: child.id,
                startAt: startAt,
                plannedEndAt: plannedEnd
            )
            applyActiveSession(childId: child.id, startedAt: startAt)
            isSessionComplete = false
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func stopSession() async {
        guard isSessionActive,
              let childId = activeChildId,
              let startAt = sessionStartAt else { return }

        let stopAt = Date()
        timerTask?.cancel()
        isSessionActive = false

        do {
            _ = try sessionRepository.recordMarker(childId: childId, type: .stop, timestamp: stopAt)
            try screenTimeService.stopMonitoring()

            usageReportRequest = (childId, startAt, stopAt)
            let payload = try await screenTimeService.fetchUsage(
                childId: childId,
                startAt: startAt,
                stopAt: stopAt
            )

            _ = try sessionRepository.saveUsageSnapshot(
                childId: childId,
                startAt: startAt,
                stopAt: stopAt,
                totalSeconds: payload.totalSeconds,
                appUsageRows: payload.apps
            )

            usageReportRequest = nil
            applyCompletedDisplay(payload: payload)
            hasTodayActivity = true
            currentDayTotalSeconds = payload.totalSeconds
            loadSummaryActivity(for: childId)
            isSessionComplete = true
            activeChildId = nil
            sessionStartAt = nil
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func endSessionEarly() {
        Task { await stopSession() }
    }

    func completeSessionFromTimer() {
        Task { await stopSession() }
    }

    func resetAfterEndScreen() {
        isSessionComplete = false
    }

    private func applyActiveSession(childId: UUID, startedAt: Date) {
        activeChildId = childId
        sessionStartAt = startedAt
        isSessionActive = true

        if plannedEndAt == nil {
            plannedEndAt = startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
        }
        remainingSeconds = max(0, Int((plannedEndAt ?? startedAt).timeIntervalSinceNow))

        startTimer()
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled, isSessionActive, remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                if let plannedEndAt {
                    remainingSeconds = max(0, Int(plannedEndAt.timeIntervalSinceNow))
                } else {
                    remainingSeconds -= 1
                }
            }

            if remainingSeconds <= 0, !Task.isCancelled, isSessionActive {
                await stopSession()
            }
        }
    }

    private func refreshScreenTimeFromAPI(for childId: UUID) async {
        isRefreshingScreenTime = true
        defer {
            isRefreshingScreenTime = false
            usageReportRequest = nil
        }

        do {
            if let today = try sessionRepository.todayActivitySummary(for: childId, referenceDate: nil) {
                hasTodayActivity = true
                let calendar = Calendar.current
                let startAt = calendar.startOfDay(for: Date())
                let stopAt = Date()
                currentDayTotalSeconds = today.totalSeconds

                usageReportRequest = (childId, startAt, stopAt)
                let payload = try await screenTimeService.fetchUsage(
                    childId: childId,
                    startAt: startAt,
                    stopAt: stopAt
                )
                currentDayTotalSeconds = payload.totalSeconds
            } else {
                hasTodayActivity = false
                currentDayTotalSeconds = 0
                await refreshLatestScreenTimeFromAPI(for: childId)
            }
        } catch {
            applyCachedBannerState(for: childId)
        }
    }

    private func refreshLatestScreenTimeFromAPI(for childId: UUID) async {
        guard let completed = try? sessionRepository.lastCompletedSession(for: childId) else {
            latestBannerTotalSeconds = 0
            latestTotalSeconds = 0
            return
        }

        latestSessionLimitSeconds = max(
            60,
            Int(completed.stoppedAt.timeIntervalSince(completed.startedAt))
        )

        usageReportRequest = (childId, completed.startedAt, completed.stoppedAt)

        do {
            let payload = try await screenTimeService.fetchUsage(
                childId: childId,
                startAt: completed.startedAt,
                stopAt: completed.stoppedAt
            )

            _ = try sessionRepository.saveUsageSnapshot(
                childId: childId,
                startAt: completed.startedAt,
                stopAt: completed.stoppedAt,
                totalSeconds: payload.totalSeconds,
                appUsageRows: payload.apps
            )

            latestBannerTotalSeconds = payload.totalSeconds
            latestTotalSeconds = payload.totalSeconds
        } catch {
            applyLatestFromCache(completed: completed)
        }
    }

    private func applyCachedBannerState(for childId: UUID) {
        if let today = try? sessionRepository.todayActivitySummary(for: childId, referenceDate: nil) {
            hasTodayActivity = true
            currentDayTotalSeconds = today.totalSeconds
            return
        }

        hasTodayActivity = false
        currentDayTotalSeconds = 0

        if let completed = try? sessionRepository.lastCompletedSession(for: childId) {
            applyLatestFromCache(completed: completed)
        } else {
            latestBannerTotalSeconds = 0
            latestTotalSeconds = 0
        }
    }

    private func applyLatestFromCache(completed: CompletedSessionInfo) {
        latestSessionLimitSeconds = max(
            60,
            Int(completed.stoppedAt.timeIntervalSince(completed.startedAt))
        )

        if let snapshot = completed.snapshot {
            latestBannerTotalSeconds = snapshot.totalSeconds
            latestTotalSeconds = snapshot.totalSeconds
        } else if let summary = try? sessionRepository.dayActivitySummary(
            for: completed.childId,
            referenceDate: nil
        ), !summary.isToday {
            latestBannerTotalSeconds = summary.totalSeconds
            latestTotalSeconds = summary.totalSeconds
        } else {
            latestBannerTotalSeconds = 0
            latestTotalSeconds = 0
        }
    }

    private func loadSummaryActivity(for childId: UUID) {
        do {
            if let summary = try sessionRepository.dayActivitySummary(for: childId, referenceDate: nil) {
                summaryPeriodTitle = summary.periodTitle
                summaryChartSessions = mapChartData(from: summary.mergedApps)
                summaryTopApps = summary.mergedApps
                hasSummaryData = true
            } else {
                resetSummaryDisplay()
            }
        } catch {
            resetSummaryDisplay()
            loadError = error.localizedDescription
        }
    }

    private func applyCompletedDisplay(payload: SessionUsagePayload) {
        latestTotalSeconds = payload.totalSeconds
    }

    private func resetDisplayState() {
        resetSummaryDisplay()
        hasTodayActivity = false
        currentDayTotalSeconds = 0
        latestBannerTotalSeconds = 0
        latestSessionLimitSeconds = 90 * 60
        latestTotalSeconds = 0
        remainingSeconds = 0
    }

    private func resetSummaryDisplay() {
        summaryPeriodTitle = "Today's Session"
        summaryChartSessions = []
        summaryTopApps = []
        hasSummaryData = false
    }

    private func mapChartData(from apps: [AppUsageRow]) -> [DashboardSessionData] {
        let palette = ["sky", "yellow", "mint", "coral"]
        return apps.prefix(4).enumerated().map { index, app in
            DashboardSessionData(
                type: app.displayName,
                duration: max(1, app.durationSeconds / 60),
                colorName: palette[index % palette.count]
            )
        }
    }

    private func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)H \(minutes)M"
        }
        return "\(max(minutes, seconds > 0 ? 1 : 0))M"
    }
}
