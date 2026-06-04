//
//  KidSessionViewModel.swift
//  team-10-c3
//

import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class KidSessionViewModel {
    private let sessionCoordinator: SessionCoordinator
    private let sessionAnalysisStore: SessionAnalysisStore?

    // MARK: - Flow (single source of truth)

    private(set) var phase: KidSessionPhase = .idle
    /// Bumped on every new session; stale async work must not apply UI after this changes.
    private var workflowGeneration: UInt64 = 0

    var selectedChild: Child?
    var remainingSeconds = 0
    /// Exact countdown length chosen in setup (minimum `SessionDurationLimits.minimumSeconds`).
    private(set) var plannedDurationSeconds = 25 * 60

    /// Analysis UI + payloads are only valid for `displaySessionId`.
    private(set) var displaySessionId: UUID?
    var isAnalyzingSession = false
    var analysisProgress = SessionAnalysisProgress.initial
    var sessionAnalysisResult: PipelineResult?
    var sessionAnalysisError: String?
    /// Shown when `prepareSession` fails (e.g. Screen Time auth or orphaned session).
    var sessionStartError: String?

    private var recordingMatchContext: SessionRecordingMatchContext?
    private var timerTask: Task<Void, Never>?
    private var postSessionAnalysisTask: Task<Void, Never>?

    let durationOptions: [Int]

    init(
        sessionCoordinator: SessionCoordinator,
        sessionAnalysisStore: SessionAnalysisStore? = nil,
        durationOptions: [Int] = [15, 30, 45, 60]
    ) {
        self.sessionCoordinator = sessionCoordinator
        self.sessionAnalysisStore = sessionAnalysisStore
        self.durationOptions = durationOptions
    }

    // MARK: - Derived (for existing views)

    var isSessionActive: Bool { phase.isActive }

    var isSessionComplete: Bool { phase.isFinished }

    var sessionIncludedScreenRecording: Bool {
        switch phase {
        case .active(let s): s.includesScreenRecording
        case .finished(let s): s.includesScreenRecording
        case .idle: false
        }
    }

    var recordingBroadcastConfirmed: Bool {
        if case .active(let s) = phase { return s.recordingBroadcastConfirmed }
        return false
    }

    var completedSessionId: UUID? { phase.finishedSessionId }

    var durationMinutes: Int {
        get { sessionCoordinator.durationMinutes }
        set {
            sessionCoordinator.durationMinutes = newValue
            plannedDurationSeconds = max(SessionDurationLimits.minimumSeconds, newValue * 60)
        }
    }

    func setPlannedDuration(seconds: Int) {
        let clamped = max(SessionDurationLimits.minimumSeconds, seconds)
        plannedDurationSeconds = clamped
        sessionCoordinator.durationMinutes = max(1, (clamped + 59) / 60)
    }

    var formattedRemainingTime: String {
        sessionCoordinator.formattedRemainingTime
    }

    var locksChildSelection: Bool {
        phase.isActive
    }

    var canStartSession: Bool {
        selectedChild != nil && !phase.isActive
    }

    func syncSelectedChild(from profileViewModel: ProfileViewModel) {
        guard !locksChildSelection else { return }
        selectedChild = profileViewModel.selectedChild
    }

    /// Resumes the single persisted active session (if any) so a new start cannot collide with DB state.
    func reconcilePersistedSession(profileViewModel: ProfileViewModel) {
        guard case .idle = phase else { return }

        Task {
            guard let active = await sessionCoordinator.reconcilePersistedActiveSession() else { return }
            guard let child = profileViewModel.children.first(where: { $0.id == active.childId }) else {
                return
            }

            profileViewModel.selectedChild = child
            selectedChild = child
            sessionCoordinator.refresh(for: child)
            remainingSeconds = sessionCoordinator.remainingSeconds

            if remainingSeconds <= 0 {
                await completeSession()
                return
            }

            phase = .active(
                ActiveKidSession(
                    sessionId: active.startMarkerId,
                    includesScreenRecording: false,
                    recordingBroadcastConfirmed: false
                )
            )
            sessionCoordinator.syncRemainingSeconds(remainingSeconds)
            startBranchTimer()
        }
    }

    // MARK: - Public actions

    func startSession(
        includesScreenRecording: Bool = false,
        recordingBroadcastConfirmed: Bool = false,
        plannedDurationSeconds explicitPlannedSeconds: Int? = nil
    ) {
        guard let child = selectedChild else { return }
        guard !phase.isActive else { return }

        sessionStartError = nil
        timerTask?.cancel()
        postSessionAnalysisTask?.cancel()
        postSessionAnalysisTask = nil

        let plannedSeconds = max(
            SessionDurationLimits.minimumSeconds,
            explicitPlannedSeconds ?? plannedDurationSeconds
        )
        setPlannedDuration(seconds: plannedSeconds)
        workflowGeneration &+= 1
        let generation = workflowGeneration

        Task {
            if sessionCoordinator.isSessionActive {
                await sessionCoordinator.stopSession()
            }

            guard generation == workflowGeneration else { return }

            remainingSeconds = plannedSeconds
            sessionCoordinator.syncRemainingSeconds(remainingSeconds)

            let prepared = await sessionCoordinator.prepareSession(
                child: child,
                plannedDurationSeconds: plannedSeconds
            )

            guard generation == workflowGeneration else { return }

            guard prepared else {
                remainingSeconds = 0
                sessionStartError = sessionCoordinator.loadError
                    ?? "Could not start the session. Check Screen Time permissions and try again."
                return
            }

            guard let sessionId = sessionCoordinator.currentSessionId else {
                remainingSeconds = 0
                sessionStartError = "Could not create a session. Please try again."
                return
            }

            clearAnalysisState()
            displaySessionId = nil

            phase = .active(
                ActiveKidSession(
                    sessionId: sessionId,
                    includesScreenRecording: includesScreenRecording,
                    recordingBroadcastConfirmed: includesScreenRecording && recordingBroadcastConfirmed
                )
            )

            if let plannedEnd = sessionCoordinator.plannedEndAt {
                remainingSeconds = max(0, Int(plannedEnd.timeIntervalSinceNow))
            }
            sessionCoordinator.syncRemainingSeconds(remainingSeconds)

            if includesScreenRecording {
                let startedAt = sessionCoordinator.sessionStartAt ?? Date()
                recordingMatchContext = RecordingManager.shared.bindActiveSessionRecording(
                    sessionId: sessionId,
                    sessionStartedAt: startedAt
                )
            }

            startBranchTimer()
        }
    }

    func endSessionEarly() {
        timerTask?.cancel()
        guard phase.isActive else { return }
        Task { await completeSession() }
    }

    /// Call from “Start New Session” — returns flow to idle and clears recording bindings.
    func resetAfterEndScreen() {
        prepareForNewSession()
        sessionCoordinator.resetAfterEndScreen()
        RecordingManager.shared.clearBroadcastActiveFlag()
        RecordingManager.shared.clearSessionRecordingBinding()
    }

    func cancelSessionAnalysis() {
        postSessionAnalysisTask?.cancel()
        postSessionAnalysisTask = nil
        isAnalyzingSession = false
        analysisProgress = .initial
    }

    /// Stop broadcast, poll for file, run pipeline — only for the finished session on screen.
    func runPostSessionAnalysisIfNeeded() {
        guard case .finished(let finished) = phase else { return }
        guard finished.includesScreenRecording else { return }

        let sessionId = finished.sessionId
        guard displaySessionId == sessionId else { return }

        if let cached = sessionAnalysisStore?.load(sessionId: sessionId) {
            applyCachedAnalysis(cached, sessionId: sessionId)
            return
        }

        guard postSessionAnalysisTask == nil else { return }

        let generation = workflowGeneration
        postSessionAnalysisTask = Task {
            defer {
                postSessionAnalysisTask = nil
                if generation == workflowGeneration, displaySessionId == sessionId {
                    isAnalyzingSession = false
                }
            }

            guard generation == workflowGeneration, displaySessionId == sessionId else { return }

            isAnalyzingSession = true
            setAnalysisProgress(
                phase: .waitingForRecording,
                fraction: 0.02,
                detail: "Stopping screen recording…"
            )

            guard let videoURL = await stopRecordingAndWaitForFile() else {
                applyFailure(
                    sessionId: sessionId,
                    generation: generation,
                    message: "Recording was not saved. Start screen recording before the session, then try again."
                )
                return
            }

            await executePipeline(videoURL: videoURL, sessionId: sessionId, generation: generation)
            recordingMatchContext = nil
        }
    }

    // MARK: - Lifecycle teardown

    /// Full reset before a new session or after leaving the result screen.
    private func clearAnalysisState() {
        postSessionAnalysisTask?.cancel()
        postSessionAnalysisTask = nil
        isAnalyzingSession = false
        analysisProgress = .initial
        sessionAnalysisResult = nil
        sessionAnalysisError = nil
        sessionStartError = nil
    }

    private func prepareForNewSession() {
        workflowGeneration &+= 1
        phase = .idle
        displaySessionId = nil

        timerTask?.cancel()
        timerTask = nil

        recordingMatchContext = nil
        remainingSeconds = 0
        clearAnalysisState()

        isSessionActiveSync(false)
    }

    private func isSessionActiveSync(_ active: Bool) {
        // Keeps coordinator branch timer in sync; no public isSessionActive stored property.
        if !active {
            sessionCoordinator.syncRemainingSeconds(0)
        }
    }

    // MARK: - Session end

    private func completeSession() async {
        timerTask?.cancel()
        let usedSeconds = sessionTimerUsedSeconds()
        remainingSeconds = 0
        sessionCoordinator.syncRemainingSeconds(0)

        let recording = sessionIncludedScreenRecording

        if sessionCoordinator.isSessionActive {
            await sessionCoordinator.stopSession(recordedElapsedSeconds: usedSeconds)
        }

        let sessionId = sessionCoordinator.currentSessionId
            ?? phase.activeSessionId
            ?? phase.finishedSessionId

        guard let sessionId else {
            phase = .idle
            displaySessionId = nil
            return
        }

        phase = .finished(
            FinishedKidSession(
                sessionId: sessionId,
                includesScreenRecording: recording
            )
        )
        displaySessionId = sessionId
        isSessionActiveSync(false)

        if recording {
            isAnalyzingSession = true
            analysisProgress = .initial
            sessionAnalysisResult = nil
            sessionAnalysisError = nil
            runPostSessionAnalysisIfNeeded()
        }
    }

    // MARK: - Analysis

    private func applyCachedAnalysis(_ cached: SessionAnalysisCacheEntry, sessionId: UUID) {
        guard displaySessionId == sessionId else { return }
        sessionAnalysisResult = cached.result
        sessionAnalysisError = cached.errorMessage
        isAnalyzingSession = false
    }

    private func applyFailure(sessionId: UUID, generation: UInt64, message: String) {
        guard generation == workflowGeneration, displaySessionId == sessionId else { return }
        sessionAnalysisError = message
        persistAnalysis(sessionId: sessionId, result: nil, errorMessage: message)
    }

    private func persistAnalysis(
        sessionId: UUID,
        result: PipelineResult?,
        errorMessage: String?
    ) {
        guard let childId = selectedChild?.id,
              let sessionAnalysisStore else { return }
        try? sessionAnalysisStore.save(
            sessionId: sessionId,
            childId: childId,
            result: result,
            errorMessage: errorMessage
        )
    }

    private func stopRecordingAndWaitForFile() async -> URL? {
        let recordingManager = RecordingManager.shared
        RecordingReadyBridge.ensureListening()
        recordingManager.postStopBroadcast()

        guard let context = recordingMatchContext else { return nil }

        let timeout: TimeInterval = 90
        let interval: TimeInterval = 0.5
        let started = Date()
        var attempt = 0

        while Date().timeIntervalSince(started) < timeout {
            if Task.isCancelled { return nil }
            attempt += 1

            if let url = recordingManager.findRecordingMatchingSession(context) {
                return url
            }

            let elapsed = Date().timeIntervalSince(started)
            setAnalysisProgress(
                phase: .waitingForRecording,
                fraction: min(0.14, 0.02 + (elapsed / timeout) * 0.12),
                detail: "Waiting for this session's recording… (\(attempt))"
            )

            try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))
        }

        return recordingManager.findRecordingMatchingSession(context)
    }

    private func sessionTimerUsedSeconds() -> Int {
        let limit = sessionCoordinator.activePlannedDurationSeconds()
        return max(0, limit - remainingSeconds)
    }

    private func startBranchTimer() {
        timerTask?.cancel()
        let generation = workflowGeneration
        timerTask = Task {
            while !Task.isCancelled, generation == workflowGeneration {
                guard case .active = phase else { return }
                guard let plannedEnd = sessionCoordinator.plannedEndAt else { return }

                let left = max(0, Int(plannedEnd.timeIntervalSinceNow))
                remainingSeconds = left
                sessionCoordinator.syncRemainingSeconds(left)

                if left <= 0 {
                    await completeSession()
                    return
                }

                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func executePipeline(
        videoURL: URL,
        sessionId: UUID,
        generation: UInt64
    ) async {
        guard generation == workflowGeneration, displaySessionId == sessionId else { return }

        let child = selectedChild
        setAnalysisProgress(phase: .loadingRecording, fraction: 0.1, detail: "Recording found")

        do {
            let output = try await SessionAnalysisRunner.runPipeline(
                videoURL: videoURL,
                child: child,
                onProgress: { [weak self] progress in
                    Task { @MainActor in
                        guard let self,
                              generation == self.workflowGeneration,
                              self.displaySessionId == sessionId else { return }
                        self.analysisProgress = progress
                    }
                }
            )
            guard generation == workflowGeneration, displaySessionId == sessionId else { return }
            let result = PipelineResult(from: output)
            sessionAnalysisResult = result
            persistAnalysis(sessionId: sessionId, result: result, errorMessage: nil)
        } catch is CancellationError {
            return
        } catch {
            guard generation == workflowGeneration, displaySessionId == sessionId else { return }
            sessionAnalysisError = error.localizedDescription
            persistAnalysis(sessionId: sessionId, result: nil, errorMessage: error.localizedDescription)
        }
    }

    private func setAnalysisProgress(
        phase: SessionAnalysisProgress.Phase,
        fraction: Double,
        detail: String? = nil
    ) {
        analysisProgress = SessionAnalysisProgress(
            phase: phase,
            fraction: min(1, max(0, fraction)),
            detail: detail
        )
    }

    #if DEBUG
    /// Preview-only configuration.
    func configureForPreview(sessionId: UUID, result: PipelineResult) {
        phase = .finished(FinishedKidSession(sessionId: sessionId, includesScreenRecording: true))
        displaySessionId = sessionId
        sessionAnalysisResult = result
    }
    #endif
}
