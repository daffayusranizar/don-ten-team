//
//  SessionCoordinator.swift
//  team-10-c3
//

import DeviceActivity
import Foundation
import Observation
import SwiftUI

/// Per-child dashboard snapshot (Latest Summary + last-session banner fields).
private struct ChildDashboardDisplayState {
    var summaryPeriodTitle = "Today"
    var summarySessionElapsedSeconds = 0
    var hasTodayActivity = false
    var currentDayTotalSeconds = 0
    var latestBannerTotalSeconds = 0
    var latestSessionLimitSeconds = 30 * 60
    var latestTotalSeconds = 0
    var sessionReportFilter: DeviceActivityFilter?
    var reportRefreshToken = ""
}

@Observable
@MainActor
final class SessionCoordinator {
    /// Grace period after planned end before an unpaired start is auto-finished on restore.
    private static let staleSessionGraceSeconds: TimeInterval = 15 * 60

    private let sessionRepository: SessionRepository
    private let screenTimeService: ScreenTimeUsageProviding
    private let familyControlsAuth: FamilyControlsAuthProviding

    var isSessionActive = false
    var isSessionPaused = false
    var isSessionComplete = false
    var sessionStartAt: Date?
    /// Start-marker id for the active / just-finished session (used for analysis cache).
    private(set) var currentSessionId: UUID?
    var plannedEndAt: Date?
    var remainingSeconds = 0
    var durationMinutes = 30
    var loadError: String?
    var summaryPeriodTitle = "Today's Session"
    var hasTodayActivity = false
    var currentDayTotalSeconds = 0
    var latestBannerTotalSeconds = 0
    var latestSessionLimitSeconds = 30 * 60
    var latestTotalSeconds = 0
    var summarySessionElapsedSeconds = 0
    var sessionReportFilter: DeviceActivityFilter?
    var reportRefreshToken = ""
    private var timerTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var childSwitchDebounceTask: Task<Void, Never>?
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

    /// Exact parent session timer for the Last Screen Time banner.
    var latestBannerDisplaySeconds: Int {
        latestTotalSeconds
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

    private var elapsedSeconds: Int {
        guard let sessionStartAt else { return 0 }
        var elapsed = Date().timeIntervalSince(sessionStartAt) - totalPausedDuration
        if isSessionPaused, let pausedAt {
            elapsed -= Date().timeIntervalSince(pausedAt)
        }
        return max(0, Int(elapsed))
    }

    var sessionProgress: Double {
        if isSessionActive {
            let limit = max(1, plannedDurationSecondsForActiveSession())
            return min(1, Double(elapsedSeconds) / Double(limit))
        }
        guard latestTotalSeconds > 0 else { return 0 }
        let limit = max(1, latestSessionLimitSeconds)
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
        let childId = child.id
        hydrateDisplayStateFromCache(for: childId, epoch: epoch)
        refreshTask = Task { @MainActor in
            await performRefresh(childId: childId, epoch: epoch)
        }
    }

    /// Child picker: show cached data immediately, debounce Screen Time + chart reload.
    func refreshAfterChildSwitch(for child: Child?) {
        childSwitchDebounceTask?.cancel()
        refreshTask?.cancel()
        guard let child else {
            resetDisplayState()
            return
        }
        let childId = child.id
        refreshChildId = childId
        refreshEpoch += 1
        let epoch = refreshEpoch
        hydrateDisplayStateFromCache(for: childId, epoch: epoch, loadChart: false)

        childSwitchDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            guard refreshEpoch == epoch, refreshChildId == childId else { return }
            refreshTask = Task { @MainActor in
                await performRefresh(childId: childId, epoch: epoch)
            }
        }
    }

    /// Defers heavy refresh until navigation / layout has settled.
    func refreshDeferred(for child: Child?, delayMilliseconds: UInt64 = 250) {
        childSwitchDebounceTask?.cancel()
        refreshTask?.cancel()
        guard let child else {
            resetDisplayState()
            return
        }
        let childId = child.id
        refreshChildId = childId
        refreshEpoch += 1
        let epoch = refreshEpoch
        hydrateDisplayStateFromCache(for: childId, epoch: epoch, loadChart: false)

        refreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(delayMilliseconds)))
            guard !Task.isCancelled else { return }
            guard refreshEpoch == epoch, refreshChildId == childId else { return }
            await performRefresh(childId: childId, epoch: epoch)
        }
    }

    /// Publishes persisted banner + day summary immediately (async Screen Time refresh follows).
    private func hydrateDisplayStateFromCache(
        for childId: UUID,
        epoch: UInt64,
        loadChart: Bool = true
    ) {
        applyCachedBannerState(for: childId, publish: false)
        if loadChart, !isSessionActive {
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
        summarySessionElapsedSeconds = state.summarySessionElapsedSeconds
        sessionReportFilter = state.sessionReportFilter
        reportRefreshToken = state.reportRefreshToken
        hasTodayActivity = state.hasTodayActivity
        currentDayTotalSeconds = state.currentDayTotalSeconds
        latestBannerTotalSeconds = state.latestBannerTotalSeconds
        latestSessionLimitSeconds = state.latestSessionLimitSeconds
        latestTotalSeconds = state.latestTotalSeconds
    }

    private func performRefresh(childId: UUID, epoch: UInt64) async {
        guard !Task.isCancelled else {
            // #region agent log
            AgentDebugLog.log(
                hypothesisId: "H3",
                location: "SessionCoordinator.performRefresh",
                message: "cancelled at entry",
                data: [
                    "childId": childId.uuidString,
                    "epoch": String(epoch),
                    "currentEpoch": String(refreshEpoch),
                ]
            )
            // #endregion
            return
        }
        do {
            let snapshotCount = (try? sessionRepository.fetchSnapshots(for: childId, month: currentMonthKey()))?
                .count ?? -1
            if let active = try sessionRepository.activeSession(for: childId) {
                currentSessionId = active.startMarkerId
                if isSessionActive, activeChildId == childId {
                    sessionStartAt = active.startedAt
                    try? await screenTimeService.activateSessionRestrictions()
                }
            } else if !(isSessionActive && activeChildId == childId), !isStoppingSession {
                clearActiveSessionState()
            }

            applyCachedBannerState(
                for: childId,
                publish: isActiveRefresh(childId: childId, epoch: epoch)
            )
            guard isActiveRefresh(childId: childId, epoch: epoch) else { return }
            await refreshScreenTimeFromAPI(for: childId, epoch: epoch)
            guard isActiveRefresh(childId: childId, epoch: epoch) else { return }
            loadSummaryActivity(for: childId, epoch: epoch)
            loadError = nil
            // #region agent log
            let daySummary = try? sessionRepository.dayActivitySummary(for: childId, referenceDate: nil)
            AgentDebugLog.log(
                hypothesisId: "H2",
                location: "SessionCoordinator.performRefresh",
                message: "performRefresh finished",
                data: [
                    "childId": childId.uuidString,
                    "epoch": String(epoch),
                    "currentEpoch": String(refreshEpoch),
                    "epochStale": String(epoch != refreshEpoch),
                    "cancelled": String(Task.isCancelled),
                    "snapshotCount": String(snapshotCount),
                    "summarySessionSeconds": String(summarySessionElapsedSeconds),
                    "hasReportFilter": String(sessionReportFilter != nil),
                    "dayTotalSeconds": String(daySummary?.totalSeconds ?? -1),
                    "daySessionCount": String(daySummary?.sessionCount ?? -1),
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
                    "childId": childId.uuidString,
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

    /// Loads the single persisted active session (if any), finishes stale/orphan rows, and mounts in memory.
    @discardableResult
    func reconcilePersistedActiveSession() async -> ActiveSessionInfo? {
        guard !isStoppingSession else { return nil }

        do {
            guard let active = try sessionRepository.resolveGlobalActiveSession() else {
                if !isSessionActive {
                    clearActiveSessionState()
                }
                return nil
            }

            if isPersistedSessionStale(active) {
                await forceCompletePersistedSession(active)
                return nil
            }

            mountPersistedActiveSession(active)
            try? await screenTimeService.activateSessionRestrictions()
            return active
        } catch {
            loadError = error.localizedDescription
            return nil
        }
    }

    /// Screen Time shields, monitoring, and start marker — no coordinator timer (branch drives countdown).
    @discardableResult
    func prepareSession(child: Child, plannedDurationSeconds: Int) async -> Bool {
        guard !isSessionActive else { return false }

        let durationMinutes = Self.durationMinutes(from: plannedDurationSeconds)

        if let persisted = try? sessionRepository.resolveGlobalActiveSession() {
            if persisted.childId == child.id {
                mountPersistedActiveSession(persisted, durationMinutes: durationMinutes)
                if remainingSeconds <= 0 {
                    await forceCompletePersistedSession(persisted)
                    return await prepareSessionAuthorized(
                        child: child,
                        plannedDurationSeconds: plannedDurationSeconds
                    )
                }
                return true
            }
            loadError = "Finish the current session before starting a new one."
            return false
        }

        return await prepareSessionAuthorized(
            child: child,
            plannedDurationSeconds: plannedDurationSeconds
        )
    }

    private static func durationMinutes(from plannedDurationSeconds: Int) -> Int {
        max(1, (max(SessionDurationLimits.minimumSeconds, plannedDurationSeconds) + 59) / 60)
    }

    func syncRemainingSeconds(_ seconds: Int) {
        remainingSeconds = max(0, seconds)
    }

    private func prepareSessionAuthorized(child: Child, plannedDurationSeconds: Int) async -> Bool {
        guard !isSessionActive else { return false }

        do {
            try await familyControlsAuth.ensureSessionAuthorization()
        } catch {
            screenTimeService.deactivateSessionRestrictions()
            loadError = familyControlsAuth.sessionPermissionBlockedMessage()
                ?? error.localizedDescription
            return false
        }

        do {
            try await screenTimeService.activateSessionRestrictions()
        } catch let error as SessionAppShieldError where error == .appsNotSelected {
            screenTimeService.deactivateSessionRestrictions()
            loadError = error.localizedDescription
            AgentDebugLog.log(
                hypothesisId: "C",
                location: "SessionCoordinator.prepareSessionAuthorized",
                message: "session blocked — allowed apps not selected",
                data: ["error": error.localizedDescription]
            )
            return false
        } catch {
            AgentDebugLog.log(
                hypothesisId: "C",
                location: "SessionCoordinator.prepareSessionAuthorized",
                message: "session shield failed; continuing without app blocking",
                data: ["error": error.localizedDescription]
            )
        }

        let seconds = max(SessionDurationLimits.minimumSeconds, plannedDurationSeconds)
        durationMinutes = Self.durationMinutes(from: seconds)
        let startAt = Date()
        let plannedEnd = startAt.addingTimeInterval(TimeInterval(seconds))
        plannedEndAt = plannedEnd
        resetPauseState()

        do {
            let markerId = RecordingManager.shared.consumeStagedRecordingSessionId() ?? UUID()
            let startMarker = try sessionRepository.recordMarker(
                childId: child.id,
                type: .start,
                timestamp: startAt,
                id: markerId
            )
            currentSessionId = startMarker.id
            try screenTimeService.startMonitoring(
                childId: child.id,
                startAt: startAt,
                plannedEndAt: plannedEnd
            )
            applyActiveSession(
                childId: child.id,
                startedAt: startAt,
                plannedDurationSeconds: seconds,
                startCoordinatorTimer: false
            )
            isSessionComplete = false
            loadError = nil
            return true
        } catch {
            loadError = error.localizedDescription
            return false
        }
    }

    /// Wall-clock planned cap for the active session (matches setup countdown).
    func activePlannedDurationSeconds() -> Int {
        plannedDurationSecondsForActiveSession()
    }

    func stopSession(recordedElapsedSeconds: Int? = nil) async {
        guard isSessionActive,
              let childId = activeChildId,
              let startAt = sessionStartAt else { return }
        guard !isStoppingSession else { return }

        isStoppingSession = true
        defer { isStoppingSession = false }

        let stopAt = Date()
        let plannedSeconds = plannedDurationSecondsForActiveSession()
        let wallClock = wallClockElapsedSeconds(from: startAt, to: stopAt)
        let elapsedSeconds: Int = if let recorded = recordedElapsedSeconds {
            max(0, min(recorded, plannedSeconds))
        } else {
            wallClock
        }

        timerTask?.cancel()
        resetPauseState()

        do {
            _ = try sessionRepository.recordMarker(
                childId: childId,
                type: .stop,
                timestamp: stopAt,
                id: UUID()
            )
            try? screenTimeService.stopMonitoring()
            screenTimeService.deactivateSessionRestrictions()
        } catch {
            loadError = error.localizedDescription
            try? screenTimeService.stopMonitoring()
            screenTimeService.deactivateSessionRestrictions()
        }

        isSessionActive = false

        do {
            let snapshot = try sessionRepository.saveUsageSnapshot(
                childId: childId,
                startAt: startAt,
                stopAt: stopAt,
                totalSeconds: elapsedSeconds,
                plannedDurationSeconds: plannedSeconds
            )

            applyCompletedDisplay(
                childId: childId,
                startAt: startAt,
                stopAt: stopAt,
                snapshot: snapshot
            )
            mutateChildDisplayState(for: childId, publish: refreshChildId == childId) { state in
                if let today = try? sessionRepository.todayActivitySummary(for: childId, referenceDate: nil) {
                    state.hasTodayActivity = today.totalSeconds > 0
                    state.currentDayTotalSeconds = today.totalSeconds
                } else {
                    state.hasTodayActivity = elapsedSeconds > 0
                    state.currentDayTotalSeconds = elapsedSeconds
                }
            }
            loadSummaryActivity(for: childId, publishUI: refreshChildId == childId, bumpReport: true)
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
        isSessionActive = false
        currentSessionId = nil
        activeChildId = nil
        sessionStartAt = nil
        plannedEndAt = nil
        remainingSeconds = 0
        timerTask?.cancel()
        resetPauseState()
    }

    private func mountPersistedActiveSession(
        _ active: ActiveSessionInfo,
        durationMinutes overrideMinutes: Int? = nil
    ) {
        if let overrideMinutes {
            durationMinutes = overrideMinutes
        }
        currentSessionId = active.startMarkerId
        applyActiveSession(
            childId: active.childId,
            startedAt: active.startedAt,
            startCoordinatorTimer: false
        )
    }

    private func isPersistedSessionStale(_ active: ActiveSessionInfo) -> Bool {
        let plannedEnd = active.startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
        return Date() > plannedEnd.addingTimeInterval(Self.staleSessionGraceSeconds)
    }

    private func forceCompletePersistedSession(_ active: ActiveSessionInfo) async {
        guard !isStoppingSession else { return }

        isStoppingSession = true
        defer { isStoppingSession = false }

        let stopAt = Date()
        let elapsedSeconds = max(0, Int(stopAt.timeIntervalSince(active.startedAt)))
        let plannedSeconds = max(
            SessionDurationLimits.minimumSeconds,
            durationMinutes * 60
        )

        do {
            _ = try sessionRepository.recordMarker(
                childId: active.childId,
                type: .stop,
                timestamp: stopAt,
                id: UUID()
            )
            try? screenTimeService.stopMonitoring()
            screenTimeService.deactivateSessionRestrictions()

            let snapshot = try sessionRepository.saveUsageSnapshot(
                childId: active.childId,
                startAt: active.startedAt,
                stopAt: stopAt,
                totalSeconds: elapsedSeconds,
                plannedDurationSeconds: plannedSeconds
            )
            applyCompletedDisplay(
                childId: active.childId,
                startAt: active.startedAt,
                stopAt: stopAt,
                snapshot: snapshot
            )
        } catch {
            loadError = error.localizedDescription
        }

        isSessionActive = false
        isSessionComplete = true
        activeChildId = nil
        sessionStartAt = nil
        plannedEndAt = nil
        currentSessionId = nil
        remainingSeconds = 0
        timerTask?.cancel()
        resetPauseState()
    }

    private func applyActiveSession(
        childId: UUID,
        startedAt: Date,
        plannedDurationSeconds explicitSeconds: Int? = nil,
        startCoordinatorTimer: Bool = true
    ) {
        activeChildId = childId
        sessionStartAt = startedAt
        isSessionActive = true
        isSessionComplete = false

        if let explicitSeconds {
            let seconds = max(SessionDurationLimits.minimumSeconds, explicitSeconds)
            plannedEndAt = startedAt.addingTimeInterval(TimeInterval(seconds))
        } else if plannedEndAt == nil {
            plannedEndAt = startedAt.addingTimeInterval(
                TimeInterval(max(SessionDurationLimits.minimumSeconds, durationMinutes * 60))
            )
        }
        remainingSeconds = max(0, Int(plannedEndAt!.timeIntervalSinceNow))

        if startCoordinatorTimer {
            startTimer()
        }
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
        screenTimeService.deactivateSessionRestrictions()
        isSessionActive = false
        activeChildId = nil
        timerTask?.cancel()
        resetPauseState()
    }

    private func refreshScreenTimeFromAPI(for childId: UUID, epoch: UInt64) async {
        let publish = isActiveRefresh(childId: childId, epoch: epoch)
        mutateChildDisplayState(for: childId, publish: publish) { state in
            if let today = try? sessionRepository.todayActivitySummary(for: childId, referenceDate: nil) {
                state.hasTodayActivity = true
                state.currentDayTotalSeconds = today.totalSeconds
            } else {
                state.hasTodayActivity = false
                state.currentDayTotalSeconds = 0
            }
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

        let publish = isActiveRefresh(childId: childId, epoch: epoch)
        loadSummaryActivity(for: childId, epoch: epoch, publishUI: publish)
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
        plannedLimitSeconds overridePlannedLimit: Int? = nil,
        into state: inout ChildDashboardDisplayState
    ) {
        state.latestSessionLimitSeconds = overridePlannedLimit ?? plannedLimitSeconds(for: completed)
        let wallClock = completed.snapshot?.totalSeconds
            ?? max(0, Int(completed.stoppedAt.timeIntervalSince(completed.startedAt)))
        state.latestTotalSeconds = wallClock
        state.latestBannerTotalSeconds = wallClock
    }

    private func applyLatestFromCache(
        completed: CompletedSessionInfo,
        into state: inout ChildDashboardDisplayState
    ) {
        applyLastSessionBanner(completed: completed, into: &state)
    }

    private func loadSummaryActivity(
        for childId: UUID,
        epoch: UInt64 = 0,
        publishUI: Bool? = nil,
        bumpReport: Bool = false
    ) {
        let publish = publishUI ?? isActiveRefresh(childId: childId, epoch: epoch)
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
                        "sessionCount": String(summary.sessionCount),
                        "periodTitle": summary.periodTitle,
                    ]
                )
                // #endregion
                applyTimerSummaryFromDaySummary(summary, for: childId, publish: publish, bumpReport: bumpReport)
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

    private func activeSessionInfo(for childId: UUID) -> ActiveSessionInfo? {
        guard isSessionActive,
              activeChildId == childId,
              let sessionStartAt,
              let currentSessionId else {
            return nil
        }
        return ActiveSessionInfo(
            childId: childId,
            startedAt: sessionStartAt,
            startMarkerId: currentSessionId
        )
    }

    private func applyTimerSummaryFromDaySummary(
        _ summary: DayActivitySummary,
        for childId: UUID,
        publish: Bool,
        bumpReport: Bool
    ) {
        if summary.totalSeconds > 0 || summary.sessionCount > 0 {
            mutateChildDisplayState(for: childId, publish: publish) { state in
                state.summaryPeriodTitle = summary.periodTitle
                state.summarySessionElapsedSeconds = summary.totalSeconds
                state.sessionReportFilter = SessionReportFilterProvider.todayReportFilter(
                    childId: childId,
                    day: summary.day,
                    sessionRepository: sessionRepository,
                    activeSession: activeSessionInfo(for: childId)
                )
                if bumpReport || state.reportRefreshToken.isEmpty {
                    state.reportRefreshToken = UUID().uuidString
                }
            }
            return
        }
        resetSummaryDisplay(for: childId, publish: publish)
    }

    func bumpReportRefresh() {
        guard let childId = refreshChildId else { return }
        loadSummaryActivity(for: childId, bumpReport: true)
    }

    private func applyCompletedDisplay(
        childId: UUID,
        startAt: Date,
        stopAt: Date,
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
            applyLastSessionBanner(completed: completed, into: &state)
        }
        publishChildDisplayState(for: childId)
        loadSummaryActivity(for: childId, bumpReport: true)
    }

    private func plannedDurationSecondsForActiveSession() -> Int {
        if let plannedEndAt, let sessionStartAt {
            return max(
                SessionDurationLimits.minimumSeconds,
                Int(plannedEndAt.timeIntervalSince(sessionStartAt))
            )
        }
        return max(SessionDurationLimits.minimumSeconds, durationMinutes * 60)
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
        summarySessionElapsedSeconds = 0
        sessionReportFilter = nil
        reportRefreshToken = ""
        hasTodayActivity = false
        currentDayTotalSeconds = 0
        latestBannerTotalSeconds = 0
        latestSessionLimitSeconds = 30 * 60
        latestTotalSeconds = 0
        remainingSeconds = 0
    }

    private func resetSummaryDisplay(for childId: UUID, publish: Bool) {
        mutateChildDisplayState(for: childId, publish: publish) { state in
            state.summaryPeriodTitle = "Today"
            state.summarySessionElapsedSeconds = 0
            state.sessionReportFilter = nil
        }
    }

    private func formatDuration(seconds: Int) -> String {
        DurationFormatting.compact(seconds: seconds)
    }

}
