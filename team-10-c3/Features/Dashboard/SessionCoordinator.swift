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
    let durationSeconds: Int
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

/// Per-child dashboard snapshot (Latest Summary + last-session banner fields).
private struct ChildDashboardDisplayState {
    var summaryPeriodTitle = "Today"
    var summaryChartSessions: [DashboardSessionData] = []
    var summaryTopApps: [AppUsageRow] = []
    var hasSummaryData = false
    var summarySessionElapsedSeconds = 0
    var summaryScreenTimeAppTotalSeconds = 0
    var hasTodayActivity = false
    var currentDayTotalSeconds = 0
    var latestBannerTotalSeconds = 0
    var latestSessionLimitSeconds = 30 * 60
    var latestTotalSeconds = 0
    var latestScreenTimeAppTotalSeconds = 0
}

@Observable
@MainActor
final class SessionCoordinator {
    private let sessionRepository: SessionRepository
    private let screenTimeService: ScreenTimeUsageProviding
    private let familyControlsAuth: FamilyControlsAuthProviding

    var isSessionActive = false
    var isSessionPaused = false
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
    var latestSessionLimitSeconds = 30 * 60
    var isRefreshingScreenTime = false
    var isRefreshingPartialUsage = false
    var latestTotalSeconds = 0
    var latestScreenTimeAppTotalSeconds = 0
    var summarySessionElapsedSeconds = 0
    var summaryScreenTimeAppTotalSeconds = 0
    private var timerTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var activeChildId: UUID?
    private var pausedAt: Date?
    private var totalPausedDuration: TimeInterval = 0
    private var isStoppingSession = false
    /// Bumped on each `refresh(for:)` to detect stale async completions (H1).
    private var refreshEpoch: UInt64 = 0
    /// Child id for the in-flight / latest `refresh(for:)` — stale refreshes must not touch UI.
    private var refreshChildId: UUID?
    /// Latest Summary and banner numbers keyed by child (survives child switch).
    private var displayStateByChild: [UUID: ChildDashboardDisplayState] = [:]

    let durationOptions = [15, 30, 45, 60]

    init(
        sessionRepository: SessionRepository,
        screenTimeService: ScreenTimeUsageProviding,
        familyControlsAuth: FamilyControlsAuthProviding
    ) {
        self.sessionRepository = sessionRepository
        self.screenTimeService = screenTimeService
        self.familyControlsAuth = familyControlsAuth
    }

    var formattedRemainingTime: String {
        DurationFormatting.compact(seconds: remainingSeconds)
    }

    var formattedElapsedOrTotal: String {
        formatDuration(seconds: isSessionActive ? elapsedSeconds : latestTotalSeconds)
    }

    var formattedCurrentDayTotal: String {
        formatDuration(seconds: currentDayTotalSeconds)
    }

    var formattedLatestBannerTotal: String {
        formatDuration(seconds: latestBannerDisplaySeconds)
    }

    /// Wall-clock until Screen Time apps arrive; then per-app Screen Time total.
    var latestBannerDisplaySeconds: Int {
        if latestScreenTimeAppTotalSeconds > 0 {
            return latestScreenTimeAppTotalSeconds
        }
        return latestTotalSeconds
    }

    var currentDayProgress: Double {
        let limit = max(1, durationMinutes * 60)
        return min(1, Double(currentDayTotalSeconds) / Double(limit))
    }

    var latestBannerProgress: Double {
        let limit = max(1, latestSessionLimitSeconds)
        return min(1, Double(latestBannerDisplaySeconds) / Double(limit))
    }

    var formattedTimeLimit: String {
        formatDuration(seconds: durationMinutes * 60)
    }

    var formattedSessionElapsed: String {
        formatDuration(seconds: elapsedSeconds)
    }

    var formattedSessionRemaining: String {
        formatDuration(seconds: remainingSeconds)
    }

    var formattedVerboseTimeLimit: String {
        DurationFormatting.verbose(seconds: durationMinutes * 60)
    }

    var formattedSummaryScreenTimeAppTotal: String {
        formatDuration(seconds: summaryScreenTimeAppTotalSeconds)
    }

    var showsScreenTimeTotalsMismatch: Bool {
        guard summarySessionElapsedSeconds > 0, summaryScreenTimeAppTotalSeconds > 0 else {
            return false
        }
        let delta = abs(summaryScreenTimeAppTotalSeconds - summarySessionElapsedSeconds)
        return Double(delta) / Double(summarySessionElapsedSeconds) > 0.10
    }

    private var elapsedSeconds: Int {
        guard let sessionStartAt else { return 0 }
        var elapsed = Date().timeIntervalSince(sessionStartAt) - totalPausedDuration
        if isSessionPaused, let pausedAt {
            elapsed -= Date().timeIntervalSince(pausedAt)
        }
        return max(0, Int(elapsed))
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
        refreshTask?.cancel()
        guard let child else {
            // #region agent log
            AgentDebugLog.log(
                hypothesisId: "H2",
                location: "SessionCoordinator.refresh",
                message: "refresh nil child — resetDisplayState",
                data: [:]
            )
            // #endregion
            resetDisplayState()
            return
        }
        refreshChildId = child.id
        refreshEpoch += 1
        let epoch = refreshEpoch
        // #region agent log
        AgentDebugLog.log(
            hypothesisId: "H1",
            location: "SessionCoordinator.refresh",
            message: "refresh started",
            data: [
                "childId": child.id.uuidString,
                "childName": child.name,
                "epoch": String(epoch),
            ]
        )
        // #endregion
        hydrateDisplayStateFromCache(for: child.id, epoch: epoch)
        refreshTask = Task { await performRefresh(for: child, epoch: epoch) }
    }

    /// Publishes persisted banner + day summary immediately (async Screen Time refresh follows).
    private func hydrateDisplayStateFromCache(for childId: UUID, epoch: UInt64) {
        applyCachedBannerState(for: childId, publish: false)
        if !isSessionActive {
            loadSummaryActivity(for: childId, epoch: epoch)
        }
        publishChildDisplayState(for: childId)
    }

    /// Only the latest child switch refresh may update dashboard summary/banner from async work.
    private func isActiveRefresh(childId: UUID, epoch: UInt64) -> Bool {
        guard refreshChildId == childId else { return false }
        if epoch > 0 { return epoch == refreshEpoch }
        return true
    }

    private func childDisplayState(for childId: UUID) -> ChildDashboardDisplayState {
        displayStateByChild[childId] ?? ChildDashboardDisplayState()
    }

    private func mutateChildDisplayState(
        for childId: UUID,
        publish: Bool,
        _ body: (inout ChildDashboardDisplayState) -> Void
    ) {
        var state = childDisplayState(for: childId)
        body(&state)
        displayStateByChild[childId] = state
        if publish, refreshChildId == childId {
            applyDisplayStateToPublished(state)
        }
    }

    private func publishChildDisplayState(for childId: UUID) {
        applyDisplayStateToPublished(childDisplayState(for: childId))
    }

    private func applyDisplayStateToPublished(_ state: ChildDashboardDisplayState) {
        summaryPeriodTitle = state.summaryPeriodTitle
        summaryChartSessions = state.summaryChartSessions
        summaryTopApps = state.summaryTopApps
        hasSummaryData = state.hasSummaryData
        summarySessionElapsedSeconds = state.summarySessionElapsedSeconds
        summaryScreenTimeAppTotalSeconds = state.summaryScreenTimeAppTotalSeconds
        hasTodayActivity = state.hasTodayActivity
        currentDayTotalSeconds = state.currentDayTotalSeconds
        latestBannerTotalSeconds = state.latestBannerTotalSeconds
        latestSessionLimitSeconds = state.latestSessionLimitSeconds
        latestTotalSeconds = state.latestTotalSeconds
        latestScreenTimeAppTotalSeconds = state.latestScreenTimeAppTotalSeconds
    }

    private func performRefresh(for child: Child, epoch: UInt64) async {
        guard !Task.isCancelled else {
            // #region agent log
            AgentDebugLog.log(
                hypothesisId: "H3",
                location: "SessionCoordinator.performRefresh",
                message: "cancelled at entry",
                data: [
                    "childId": child.id.uuidString,
                    "epoch": String(epoch),
                    "currentEpoch": String(refreshEpoch),
                ]
            )
            // #endregion
            return
        }
        do {
            let snapshotCount = (try? sessionRepository.fetchSnapshots(for: child.id, month: currentMonthKey()))?
                .count ?? -1
            if let active = try sessionRepository.activeSession(for: child.id) {
                applyActiveSession(childId: child.id, startedAt: active.startedAt)
            } else if !(isSessionActive && activeChildId == child.id), !isStoppingSession {
                clearActiveSessionState()
            }

            applyCachedBannerState(
                for: child.id,
                publish: isActiveRefresh(childId: child.id, epoch: epoch)
            )
            guard isActiveRefresh(childId: child.id, epoch: epoch) else { return }
            await refreshScreenTimeFromAPI(for: child.id, epoch: epoch)
            guard isActiveRefresh(childId: child.id, epoch: epoch) else { return }
            if !isSessionActive {
                loadSummaryActivity(for: child.id, epoch: epoch)
            }
            loadError = nil
            // #region agent log
            let daySummary = try? sessionRepository.dayActivitySummary(for: child.id, referenceDate: nil)
            AgentDebugLog.log(
                hypothesisId: "H2",
                location: "SessionCoordinator.performRefresh",
                message: "performRefresh finished",
                data: [
                    "childId": child.id.uuidString,
                    "epoch": String(epoch),
                    "currentEpoch": String(refreshEpoch),
                    "epochStale": String(epoch != refreshEpoch),
                    "cancelled": String(Task.isCancelled),
                    "snapshotCount": String(snapshotCount),
                    "hasSummaryData": String(hasSummaryData),
                    "summaryApps": String(summaryTopApps.count),
                    "summarySessionSeconds": String(summarySessionElapsedSeconds),
                    "dayTotalSeconds": String(daySummary?.totalSeconds ?? -1),
                    "dayMergedApps": String(daySummary?.mergedApps.count ?? -1),
                ]
            )
            // #endregion
        } catch {
            loadError = error.localizedDescription
            // #region agent log
            AgentDebugLog.log(
                hypothesisId: "H2",
                location: "SessionCoordinator.performRefresh",
                message: "performRefresh error",
                data: [
                    "childId": child.id.uuidString,
                    "epoch": String(epoch),
                    "error": error.localizedDescription,
                ]
            )
            // #endregion
        }
    }

    private func currentMonthKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }

    func startSession(child: Child, durationMinutes: Int) {
        guard !isSessionActive else { return }

        familyControlsAuth.refreshAuthorizationStatus()
        if let blocked = familyControlsAuth.recordingBlockedMessage() {
            loadError = blocked
            return
        }

        self.durationMinutes = durationMinutes
        let startAt = Date()
        let plannedEnd = startAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
        plannedEndAt = plannedEnd
        resetPauseState()

        do {
            _ = try sessionRepository.recordMarker(childId: child.id, type: .start, timestamp: startAt)
            try? screenTimeService.startMonitoring(
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
        guard !isStoppingSession else { return }

        isStoppingSession = true
        defer { isStoppingSession = false }

        let stopAt = Date()
        let elapsedSeconds = wallClockElapsedSeconds(from: startAt, to: stopAt)

        timerTask?.cancel()
        resetPauseState()

        var savedTotalSeconds = elapsedSeconds
        var savedApps: [AppUsageRow] = []
        var fetchError: String?

        do {
            _ = try sessionRepository.recordMarker(childId: childId, type: .stop, timestamp: stopAt)

            isRefreshingScreenTime = true
            defer { isRefreshingScreenTime = false }

            let payload = try await screenTimeService.fetchUsage(
                childId: childId,
                startAt: startAt,
                stopAt: stopAt
            )
            // #region agent log
            ScreenTimePipelineLogger.logOutput(
                stage: "afterFetch",
                apps: payload.apps,
                sessionElapsedSeconds: elapsedSeconds
            )
            AgentDebugLog.log(
                hypothesisId: "E",
                location: "SessionCoordinator.stopSession:afterFetch",
                message: "fetch completed",
                data: [
                    "appCount": String(payload.apps.count),
                    "appSumSeconds": String(payload.apps.map(\.durationSeconds).reduce(0, +)),
                    "appsList": ScreenTimePipelineLogger.formatApps(payload.apps),
                    "payloadTotalSeconds": String(payload.totalSeconds),
                    "elapsedSeconds": String(elapsedSeconds),
                ]
            )
            // #endregion
            savedApps = payload.apps
            savedTotalSeconds = elapsedSeconds
            latestScreenTimeAppTotalSeconds = payload.apps.map(\.durationSeconds).reduce(0, +)
            try? screenTimeService.stopMonitoring()
        } catch {
            fetchError = error.localizedDescription
            try? screenTimeService.stopMonitoring()
        }

        isSessionActive = false

        do {
            let snapshot = try sessionRepository.saveUsageSnapshot(
                childId: childId,
                startAt: startAt,
                stopAt: stopAt,
                totalSeconds: savedTotalSeconds,
                plannedDurationSeconds: durationMinutes * 60,
                appUsageRows: savedApps
            )
            // #region agent log
            ScreenTimePipelineLogger.logOutput(
                stage: "afterSave",
                apps: snapshot.appUsageRows,
                sessionElapsedSeconds: savedTotalSeconds,
                extra: [
                    "savedScreenTimeAppTotal": String(snapshot.screenTimeAppTotalSeconds),
                    "fetchError": fetchError ?? "none",
                ]
            )
            AgentDebugLog.log(
                hypothesisId: "E",
                location: "SessionCoordinator.stopSession:afterSave",
                message: "snapshot saved",
                data: [
                    "childId": childId.uuidString,
                    "savedTotalSeconds": String(savedTotalSeconds),
                    "savedScreenTimeAppTotal": String(snapshot.screenTimeAppTotalSeconds),
                    "savedAppCount": String(savedApps.count),
                    "snapshotAppCount": String(snapshot.appUsageRows.count),
                    "appsList": ScreenTimePipelineLogger.formatApps(snapshot.appUsageRows),
                    "snapshotJSONLength": String(snapshot.appUsageJSON.count),
                    "fetchError": fetchError ?? "none",
                ]
            )
            // #endregion

            applyCompletedDisplay(
                childId: childId,
                startAt: startAt,
                stopAt: stopAt,
                totalSeconds: savedTotalSeconds,
                apps: savedApps,
                snapshot: snapshot
            )
            mutateChildDisplayState(for: childId, publish: refreshChildId == childId) { state in
                if let today = try? sessionRepository.todayActivitySummary(for: childId, referenceDate: nil) {
                    state.hasTodayActivity = today.totalSeconds > 0
                    state.currentDayTotalSeconds = today.totalSeconds
                } else {
                    state.hasTodayActivity = savedTotalSeconds > 0
                    state.currentDayTotalSeconds = savedTotalSeconds
                }
            }
            loadError = fetchError

            if savedApps.isEmpty || !usageBackfillIsRichEnough(savedApps) {
                scheduleUsageBackfill(
                    childId: childId,
                    startAt: startAt,
                    stopAt: stopAt,
                    elapsedSeconds: elapsedSeconds,
                    initialApps: savedApps
                )
            }
        } catch {
            loadError = error.localizedDescription
        }

        isSessionComplete = true
        activeChildId = nil
        sessionStartAt = nil
        plannedEndAt = nil
    }

    func addAdditionalTime(seconds: Int) {
        guard seconds > 0 else { return }

        durationMinutes += max(1, Int(ceil(Double(seconds) / 60)))

        if isSessionActive {
            let base = plannedEndAt ?? Date()
            plannedEndAt = base.addingTimeInterval(TimeInterval(seconds))
            if isSessionPaused {
                remainingSeconds += seconds
            } else {
                remainingSeconds = max(0, Int(plannedEndAt!.timeIntervalSinceNow))
            }
        }
    }

    func togglePause() {
        guard isSessionActive else { return }
        if isSessionPaused {
            resumeSession()
        } else {
            pauseSession()
        }
    }

    func pauseSession() {
        guard isSessionActive, !isSessionPaused else { return }
        isSessionPaused = true
        pausedAt = Date()
        Task { await refreshPartialUsage() }
    }

    func resumeSession() {
        guard isSessionActive, isSessionPaused, let pauseStart = pausedAt else { return }

        let pauseDuration = Date().timeIntervalSince(pauseStart)
        totalPausedDuration += pauseDuration
        if let plannedEndAt {
            self.plannedEndAt = plannedEndAt.addingTimeInterval(pauseDuration)
        }
        pausedAt = nil
        isSessionPaused = false
        remainingSeconds = max(0, Int((plannedEndAt ?? Date()).timeIntervalSinceNow))
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
        isSessionComplete = false

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
                guard !isSessionPaused else { continue }

                if let plannedEndAt {
                    remainingSeconds = max(0, Int(plannedEndAt.timeIntervalSinceNow))
                } else {
                    remainingSeconds -= 1
                }
            }

            if remainingSeconds <= 0,
               !Task.isCancelled,
               isSessionActive,
               !isSessionPaused {
                await stopSession()
            }
        }
    }

    private func resetPauseState() {
        isSessionPaused = false
        pausedAt = nil
        totalPausedDuration = 0
    }

    private func clearActiveSessionState() {
        isSessionActive = false
        activeChildId = nil
        timerTask?.cancel()
        resetPauseState()
    }

    private func refreshScreenTimeFromAPI(for childId: UUID, epoch: UInt64) async {
        if let today = try? sessionRepository.todayActivitySummary(for: childId, referenceDate: nil) {
            hasTodayActivity = true
            currentDayTotalSeconds = today.totalSeconds
        } else {
            hasTodayActivity = false
            currentDayTotalSeconds = 0
        }
        await refreshLatestScreenTimeFromAPI(for: childId, epoch: epoch)
    }

    private func refreshLatestScreenTimeFromAPI(for childId: UUID, epoch: UInt64) async {
        guard let completed = try? sessionRepository.lastCompletedSession(for: childId) else {
            // #region agent log
            AgentDebugLog.log(
                hypothesisId: "H4",
                location: "SessionCoordinator.refreshLatestScreenTimeFromAPI",
                message: "no lastCompletedSession",
                data: [
                    "childId": childId.uuidString,
                    "epoch": String(epoch),
                    "currentEpoch": String(refreshEpoch),
                ]
            )
            // #endregion
            return
        }

        mutateChildDisplayState(for: childId, publish: isActiveRefresh(childId: childId, epoch: epoch)) { state in
            applyLatestFromCache(completed: completed, into: &state)
        }

        if let snapshot = completed.snapshot, !snapshot.appUsageRows.isEmpty {
            // #region agent log
            AgentDebugLog.log(
                hypothesisId: "H1",
                location: "SessionCoordinator.refreshLatestScreenTimeFromAPI",
                message: "snapshot has apps — loadSummary early",
                data: [
                    "childId": childId.uuidString,
                    "epoch": String(epoch),
                    "currentEpoch": String(refreshEpoch),
                    "epochStale": String(epoch != refreshEpoch),
                    "appCount": String(snapshot.appUsageRows.count),
                ]
            )
            // #endregion
            loadSummaryActivity(for: childId, epoch: epoch)
            return
        }

        let showFetching = childDisplayState(for: childId).latestScreenTimeAppTotalSeconds == 0
            && childDisplayState(for: childId).latestTotalSeconds > 0
        if showFetching, isActiveRefresh(childId: childId, epoch: epoch) {
            isRefreshingScreenTime = true
        }
        defer {
            if isActiveRefresh(childId: childId, epoch: epoch) {
                isRefreshingScreenTime = false
            }
        }

        do {
            let payload = try await screenTimeService.fetchUsage(
                childId: childId,
                startAt: completed.startedAt,
                stopAt: completed.stoppedAt
            )

            let elapsedSeconds = max(
                0,
                Int(completed.stoppedAt.timeIntervalSince(completed.startedAt))
            )

            let plannedSeconds = plannedLimitSeconds(for: completed)
            let screenTimeSeconds = payload.apps.map(\.durationSeconds).reduce(0, +)
            _ = try sessionRepository.saveUsageSnapshot(
                childId: childId,
                startAt: completed.startedAt,
                stopAt: completed.stoppedAt,
                totalSeconds: elapsedSeconds,
                plannedDurationSeconds: plannedSeconds,
                appUsageRows: payload.apps
            )

            let publish = isActiveRefresh(childId: childId, epoch: epoch)
            mutateChildDisplayState(for: childId, publish: publish) { state in
                applyLastSessionBanner(
                    completed: completed,
                    screenTimeSeconds: screenTimeSeconds,
                    into: &state
                )
                if let today = try? sessionRepository.todayActivitySummary(for: childId, referenceDate: nil) {
                    state.hasTodayActivity = today.totalSeconds > 0
                    state.currentDayTotalSeconds = today.totalSeconds
                }
            }
            if !publish {
                // #region agent log
                AgentDebugLog.log(
                    hypothesisId: "H1",
                    location: "SessionCoordinator.refreshLatestScreenTimeFromAPI",
                    message: "stale fetch — updated child cache only",
                    data: ["childId": childId.uuidString, "epoch": String(epoch)]
                )
                // #endregion
            }
            // #region agent log
            AgentDebugLog.log(
                hypothesisId: "H1",
                location: "SessionCoordinator.refreshLatestScreenTimeFromAPI",
                message: "API fetch done — loadSummary",
                data: [
                    "childId": childId.uuidString,
                    "epoch": String(epoch),
                    "currentEpoch": String(refreshEpoch),
                    "epochStale": String(epoch != refreshEpoch),
                    "fetchedAppCount": String(payload.apps.count),
                ]
            )
            // #endregion
            loadSummaryActivity(for: childId, epoch: epoch)
        } catch {
            let publish = isActiveRefresh(childId: childId, epoch: epoch)
            if publish {
                mutateChildDisplayState(for: childId, publish: true) { state in
                    applyLatestFromCache(completed: completed, into: &state)
                }
                if let error = error as? ScreenTimeFetchError {
                    loadError = error.localizedDescription
                }
            }
            // #region agent log
            AgentDebugLog.log(
                hypothesisId: "H1",
                location: "SessionCoordinator.refreshLatestScreenTimeFromAPI",
                message: "API fetch failed",
                data: [
                    "childId": childId.uuidString,
                    "epoch": String(epoch),
                    "currentEpoch": String(refreshEpoch),
                    "error": String(describing: error),
                ]
            )
            // #endregion
        }
    }

    private func applyCachedBannerState(for childId: UUID, publish: Bool) {
        mutateChildDisplayState(for: childId, publish: publish) { state in
            if let today = try? sessionRepository.todayActivitySummary(for: childId, referenceDate: nil) {
                state.hasTodayActivity = true
                state.currentDayTotalSeconds = today.totalSeconds
            } else {
                state.hasTodayActivity = false
                state.currentDayTotalSeconds = 0
            }

            if let completed = try? sessionRepository.lastCompletedSession(for: childId) {
                applyLatestFromCache(completed: completed, into: &state)
            } else if !state.hasTodayActivity {
                state.latestBannerTotalSeconds = 0
                state.latestTotalSeconds = 0
            }
        }
    }

    /// Planned session cap (15/30/45/60 min) for “% of the session”, not wall-clock stop−start.
    private func plannedLimitSeconds(for completed: CompletedSessionInfo) -> Int {
        if let snapshot = completed.snapshot, snapshot.plannedDurationSeconds > 0 {
            return snapshot.plannedDurationSeconds
        }
        let wallClock = max(
            60,
            Int(completed.stoppedAt.timeIntervalSince(completed.startedAt))
        )
        return max(wallClock, durationMinutes * 60)
    }

    private func applyLastSessionBanner(
        completed: CompletedSessionInfo,
        screenTimeSeconds: Int? = nil,
        plannedLimitSeconds overridePlannedLimit: Int? = nil,
        into state: inout ChildDashboardDisplayState
    ) {
        state.latestSessionLimitSeconds = overridePlannedLimit ?? plannedLimitSeconds(for: completed)
        let wallClock = completed.snapshot?.totalSeconds
            ?? max(0, Int(completed.stoppedAt.timeIntervalSince(completed.startedAt)))
        let screen = screenTimeSeconds ?? completed.snapshot?.resolvedScreenTimeSeconds ?? 0
        state.latestScreenTimeAppTotalSeconds = screen
        state.latestTotalSeconds = max(state.latestTotalSeconds, wallClock)
        state.latestBannerTotalSeconds = screen > 0 ? screen : wallClock
    }

    private func applyLatestFromCache(
        completed: CompletedSessionInfo,
        into state: inout ChildDashboardDisplayState
    ) {
        applyLastSessionBanner(completed: completed, into: &state)
    }

    private func loadSummaryActivity(for childId: UUID, epoch: UInt64 = 0) {
        let publish = isActiveRefresh(childId: childId, epoch: epoch)
        let epochStale = epoch > 0 && epoch != refreshEpoch
        if !publish {
            // #region agent log
            AgentDebugLog.log(
                hypothesisId: "H1",
                location: "SessionCoordinator.loadSummaryActivity",
                message: "cache-only summary update",
                data: [
                    "childId": childId.uuidString,
                    "epoch": String(epoch),
                    "epochStale": String(epochStale),
                    "currentEpoch": String(refreshEpoch),
                    "refreshChildId": refreshChildId?.uuidString ?? "nil",
                ]
            )
            // #endregion
        }
        do {
            if let summary = try sessionRepository.dayActivitySummary(for: childId, referenceDate: nil) {
                // #region agent log
                AgentDebugLog.log(
                    hypothesisId: "H5",
                    location: "SessionCoordinator.loadSummaryActivity",
                    message: "apply day summary",
                    data: [
                        "childId": childId.uuidString,
                        "epoch": String(epoch),
                        "epochStale": String(epochStale),
                        "currentEpoch": String(refreshEpoch),
                        "totalSeconds": String(summary.totalSeconds),
                        "mergedApps": String(summary.mergedApps.count),
                        "sessionCount": String(summary.sessionCount),
                        "periodTitle": summary.periodTitle,
                    ]
                )
                // #endregion
                applySummaryFromDaySummary(summary, for: childId, publish: publish)
            } else {
                // #region agent log
                AgentDebugLog.log(
                    hypothesisId: "H2",
                    location: "SessionCoordinator.loadSummaryActivity",
                    message: "no dayActivitySummary — resetSummaryDisplay",
                    data: [
                        "childId": childId.uuidString,
                        "epoch": String(epoch),
                        "epochStale": String(epochStale),
                        "currentEpoch": String(refreshEpoch),
                    ]
                )
                // #endregion
                resetSummaryDisplay(for: childId, publish: publish)
            }
        } catch {
            resetSummaryDisplay(for: childId, publish: publish)
            if publish {
                loadError = error.localizedDescription
            }
            // #region agent log
            AgentDebugLog.log(
                hypothesisId: "H2",
                location: "SessionCoordinator.loadSummaryActivity",
                message: "dayActivitySummary error — reset",
                data: [
                    "childId": childId.uuidString,
                    "error": error.localizedDescription,
                ]
            )
            // #endregion
        }
    }

    private func applySummaryFromDaySummary(
        _ summary: DayActivitySummary,
        for childId: UUID,
        publish: Bool
    ) {
        if !summary.mergedApps.isEmpty {
            applySummaryDisplay(
                apps: summary.mergedApps,
                periodTitle: summary.periodTitle,
                screenTimeAppTotal: summary.screenTimeAppTotalSeconds,
                for: childId,
                publish: publish
            )
            mutateChildDisplayState(for: childId, publish: publish) { state in
                state.summarySessionElapsedSeconds = summary.totalSeconds
            }
            return
        }
        if summary.totalSeconds > 0 {
            mutateChildDisplayState(for: childId, publish: publish) { state in
                state.summaryPeriodTitle = summary.periodTitle
                state.summarySessionElapsedSeconds = summary.totalSeconds
                state.summaryScreenTimeAppTotalSeconds = summary.screenTimeAppTotalSeconds
                state.summaryChartSessions = [
                    DashboardSessionData(
                        type: "Session (no app breakdown yet)",
                        durationSeconds: summary.totalSeconds,
                        colorName: "sky"
                    ),
                ]
                state.summaryTopApps = []
                state.hasSummaryData = true
            }
            return
        }
        resetSummaryDisplay(for: childId, publish: publish)
    }

    /// Screen Time data can arrive seconds after stop; retry without blocking the UI.
    private func scheduleUsageBackfill(
        childId: UUID,
        startAt: Date,
        stopAt: Date,
        elapsedSeconds: Int,
        initialApps: [AppUsageRow]
    ) {
        let delays: [Duration] = [.seconds(5), .seconds(12), .seconds(25)]
        Task {
            var previousApps = initialApps
            for delay in delays {
                try? await Task.sleep(for: delay)
                guard !isSessionActive else { return }
                do {
                    let payload = try await screenTimeService.fetchUsage(
                        childId: childId,
                        startAt: startAt,
                        stopAt: stopAt
                    )
                    guard !payload.apps.isEmpty else { continue }

                    let newScore = ScreenTimePayloadSelector.qualityScore(
                        payload: payload,
                        wallClockSeconds: elapsedSeconds
                    )
                    let previousScore = ScreenTimePayloadSelector.qualityScore(
                        payload: SessionUsagePayload(
                            childId: childId,
                            startAt: startAt,
                            stopAt: stopAt,
                            totalSeconds: 0,
                            apps: previousApps
                        ),
                        wallClockSeconds: elapsedSeconds
                    )
                    let stable = usageBackfillIsStable(previous: previousApps, new: payload.apps)
                    let richEnough = usageBackfillIsRichEnough(payload.apps)
                    guard newScore > previousScore || stable else { continue }

                    _ = try sessionRepository.saveUsageSnapshot(
                        childId: childId,
                        startAt: startAt,
                        stopAt: stopAt,
                        totalSeconds: elapsedSeconds,
                        plannedDurationSeconds: durationMinutes * 60,
                        appUsageRows: payload.apps
                    )
                    let completed = CompletedSessionInfo(
                        childId: childId,
                        startedAt: startAt,
                        stoppedAt: stopAt,
                        snapshot: nil
                    )
                    let publish = refreshChildId == childId
                    mutateChildDisplayState(for: childId, publish: publish) { state in
                        applyLastSessionBanner(
                            completed: completed,
                            screenTimeSeconds: payload.apps.map(\.durationSeconds).reduce(0, +),
                            plannedLimitSeconds: durationMinutes * 60,
                            into: &state
                        )
                        state.hasTodayActivity = true
                        if let today = try? sessionRepository.todayActivitySummary(for: childId, referenceDate: nil) {
                            state.currentDayTotalSeconds = today.totalSeconds
                        } else {
                            state.currentDayTotalSeconds = elapsedSeconds
                        }
                    }
                    loadSummaryActivity(for: childId)
                    if publish {
                        loadError = nil
                    }
                    previousApps = payload.apps
                    if stable || richEnough { return }
                } catch {
                    if loadError == nil {
                        loadError = error.localizedDescription
                    }
                }
            }
        }
    }

    private func usageBackfillIsRichEnough(_ apps: [AppUsageRow]) -> Bool {
        apps.contains { $0.durationSeconds >= 30 }
    }

    private func usageBackfillIsStable(previous: [AppUsageRow], new: [AppUsageRow]) -> Bool {
        guard !previous.isEmpty, !new.isEmpty else { return false }
        let previousTop = Set(previous.prefix(3).map(\.bundleIdentifier))
        let newTop = Set(new.prefix(3).map(\.bundleIdentifier))
        guard previousTop == newTop else { return false }
        let previousSum = previous.map(\.durationSeconds).reduce(0, +)
        let newSum = new.map(\.durationSeconds).reduce(0, +)
        return newSum > previousSum
    }

    private func applySummaryDisplay(
        apps: [AppUsageRow],
        periodTitle: String,
        screenTimeAppTotal: Int? = nil,
        for childId: UUID,
        publish: Bool
    ) {
        let apps = SessionUsageNoiseFilter.appsForDisplay(
            SessionUsageSanitizer.sanitizedApps(apps)
        )
        let appSum = apps.map(\.durationSeconds).reduce(0, +)
        mutateChildDisplayState(for: childId, publish: publish) { state in
            state.summaryPeriodTitle = periodTitle
            state.summaryScreenTimeAppTotalSeconds = screenTimeAppTotal ?? appSum
            if apps.isEmpty {
                state.summaryChartSessions = []
                state.summaryTopApps = []
                state.hasSummaryData = false
            } else {
                state.summaryChartSessions = mapChartData(from: apps)
                state.summaryTopApps = apps
                state.hasSummaryData = true
            }
        }
    }

    private func refreshPartialUsage() async {
        guard let childId = activeChildId,
              let startAt = sessionStartAt else { return }

        isRefreshingPartialUsage = true
        defer { isRefreshingPartialUsage = false }

        let stopAt = Date()

        do {
            let payload = try await screenTimeService.fetchUsage(
                childId: childId,
                startAt: startAt,
                stopAt: stopAt
            )
            applySummaryDisplay(
                apps: payload.apps,
                periodTitle: "Current Session",
                for: childId,
                publish: true
            )
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func applyCompletedDisplay(
        childId: UUID,
        startAt: Date,
        stopAt: Date,
        totalSeconds: Int,
        apps: [AppUsageRow],
        snapshot: SessionUsageSnapshot
    ) {
        refreshChildId = childId
        let completed = CompletedSessionInfo(
            childId: childId,
            startedAt: startAt,
            stoppedAt: stopAt,
            snapshot: snapshot
        )
        mutateChildDisplayState(for: childId, publish: true) { state in
            applyLastSessionBanner(
                completed: completed,
                screenTimeSeconds: apps.map(\.durationSeconds).reduce(0, +),
                plannedLimitSeconds: durationMinutes * 60,
                into: &state
            )
        }
        publishChildDisplayState(for: childId)
        loadSummaryActivity(for: childId)
    }

    private func wallClockElapsedSeconds(from startAt: Date, to stopAt: Date) -> Int {
        var elapsed = stopAt.timeIntervalSince(startAt) - totalPausedDuration
        if isSessionPaused, let pausedAt {
            elapsed -= stopAt.timeIntervalSince(pausedAt)
        }
        return max(0, Int(elapsed))
    }

    private func resetDisplayState() {
        summaryPeriodTitle = "Today"
        summaryChartSessions = []
        summaryTopApps = []
        hasSummaryData = false
        summarySessionElapsedSeconds = 0
        summaryScreenTimeAppTotalSeconds = 0
        hasTodayActivity = false
        currentDayTotalSeconds = 0
        latestBannerTotalSeconds = 0
        latestSessionLimitSeconds = 30 * 60
        latestTotalSeconds = 0
        latestScreenTimeAppTotalSeconds = 0
        remainingSeconds = 0
    }

    private func resetSummaryDisplay(for childId: UUID, publish: Bool) {
        mutateChildDisplayState(for: childId, publish: publish) { state in
            state.summaryPeriodTitle = "Today"
            state.summaryChartSessions = []
            state.summaryTopApps = []
            state.hasSummaryData = false
            state.summarySessionElapsedSeconds = 0
            state.summaryScreenTimeAppTotalSeconds = 0
        }
    }

    private func mapChartData(from apps: [AppUsageRow]) -> [DashboardSessionData] {
        let palette = ["sky", "yellow", "mint", "coral"]
        return apps.enumerated().map { index, app in
            DashboardSessionData(
                type: chartLabel(for: app),
                durationSeconds: app.durationSeconds,
                colorName: palette[index % palette.count]
            )
        }
    }

    private func chartLabel(for app: AppUsageRow) -> String {
        let name = app.displayName
        if name.count <= 10 { return name }
        return String(name.prefix(9)) + "…"
    }

    private func formatDuration(seconds: Int) -> String {
        DurationFormatting.compact(seconds: seconds)
    }

}
