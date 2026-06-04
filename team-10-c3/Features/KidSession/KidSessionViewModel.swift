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

    var selectedChild: Child?
    var isSessionActive = false
    var isSessionComplete = false
    var remainingSeconds = 0
    /// True when the user enabled "Record your screen" for this session.
    var sessionIncludedScreenRecording = false
    /// True when ReplayKit broadcast was active when the recorded session began.
    var recordingBroadcastConfirmed = false
    /// Start-marker id for the session that just ended (analysis cache key).
    private(set) var completedSessionId: UUID?

    var isAnalyzingSession = false
    var analysisProgress = SessionAnalysisProgress.initial
    var sessionAnalysisResult: PipelineResult?
    var sessionAnalysisError: String?

    private var timerTask: Task<Void, Never>?
    private var postSessionAnalysisTask: Task<Void, Never>?
    /// Prevents re-running analysis when navigating back within the same session.
    private var analyzedSessionId: UUID?
    /// Baseline + session id used to pick the correct MP4 (not the previous session's file).
    private var recordingMatchContext: SessionRecordingMatchContext?

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

    var durationMinutes: Int {
        get { sessionCoordinator.durationMinutes }
        set { sessionCoordinator.durationMinutes = newValue }
    }

    var formattedRemainingTime: String {
        sessionCoordinator.formattedRemainingTime
    }

    var canStartSession: Bool {
        selectedChild != nil && !isSessionActive
    }

    func syncSelectedChild(from profileViewModel: ProfileViewModel) {
        selectedChild = profileViewModel.selectedChild
    }

    func startSession(
        includesScreenRecording: Bool = false,
        recordingBroadcastConfirmed: Bool = false
    ) {
        guard let child = selectedChild else { return }
        guard !isSessionActive else { return }

        sessionIncludedScreenRecording = includesScreenRecording
        self.recordingBroadcastConfirmed = includesScreenRecording && recordingBroadcastConfirmed
        completedSessionId = nil
        analyzedSessionId = nil
        recordingMatchContext = nil
        clearAnalysisState()
        timerTask?.cancel()
        let plannedSeconds = durationMinutes * 60
        remainingSeconds = plannedSeconds
        isSessionComplete = false

        Task {
            let prepared = await sessionCoordinator.prepareSession(
                child: child,
                durationMinutes: durationMinutes
            )
            guard prepared else {
                remainingSeconds = 0
                return
            }

            isSessionActive = true
            sessionCoordinator.syncRemainingSeconds(remainingSeconds)

            if sessionIncludedScreenRecording,
               let sessionId = sessionCoordinator.currentSessionId {
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
        guard isSessionActive || sessionCoordinator.isSessionActive else { return }
        Task { await completeSession() }
    }

    func resetAfterEndScreen() {
        postSessionAnalysisTask?.cancel()
        postSessionAnalysisTask = nil
        isAnalyzingSession = false
        analysisProgress = .initial
        isSessionComplete = false
        completedSessionId = nil
        analyzedSessionId = nil
        sessionIncludedScreenRecording = false
        recordingBroadcastConfirmed = false
        recordingMatchContext = nil
        clearAnalysisState()
        sessionCoordinator.resetAfterEndScreen()
        RecordingManager.shared.clearBroadcastActiveFlag()
        RecordingManager.shared.clearSessionRecordingBinding()
    }

    // MARK: - Session end

    /// Ends Screen Time, opens session-complete UI, then runs analysis once for this session id.
    private func completeSession() async {
        timerTask?.cancel()
        isSessionActive = false
        remainingSeconds = 0
        sessionCoordinator.syncRemainingSeconds(0)

        if sessionCoordinator.isSessionActive {
            await sessionCoordinator.stopSession()
        }

        completedSessionId = sessionCoordinator.currentSessionId

        if sessionIncludedScreenRecording {
            isAnalyzingSession = true
            analysisProgress = .initial
            sessionAnalysisResult = nil
            sessionAnalysisError = nil
        }

        isSessionComplete = true

        if sessionIncludedScreenRecording {
            runPostSessionAnalysisIfNeeded()
        }
    }

    /// Stop broadcast, poll for file, run pipeline — once per `completedSessionId` (SwiftData + memory guard).
    func runPostSessionAnalysisIfNeeded() {
        guard sessionIncludedScreenRecording else { return }
        guard let sessionId = completedSessionId else { return }
        guard analyzedSessionId != sessionId else { return }

        if let cached = sessionAnalysisStore?.load(sessionId: sessionId) {
            applyCachedAnalysis(cached, sessionId: sessionId)
            return
        }

        guard postSessionAnalysisTask == nil else { return }

        postSessionAnalysisTask = Task {
            defer {
                postSessionAnalysisTask = nil
                isAnalyzingSession = false
            }

            isAnalyzingSession = true
            setAnalysisProgress(
                phase: .waitingForRecording,
                fraction: 0.02,
                detail: "Stopping screen recording…"
            )

            guard let videoURL = await stopRecordingAndWaitForFile() else {
                let message =
                    "Recording was not saved. Start screen recording before the session, then try again."
                sessionAnalysisError = message
                persistAnalysis(sessionId: sessionId, result: nil, errorMessage: message)
                analyzedSessionId = sessionId
                return
            }

            await executePipeline(videoURL: videoURL, sessionId: sessionId)
            analyzedSessionId = sessionId
            recordingMatchContext = nil
        }
    }

    private func applyCachedAnalysis(_ cached: SessionAnalysisCacheEntry, sessionId: UUID) {
        sessionAnalysisResult = cached.result
        sessionAnalysisError = cached.errorMessage
        analyzedSessionId = sessionId
        isAnalyzingSession = false
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

        guard let context = recordingMatchContext else {
            return nil
        }

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

    private func startBranchTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while remainingSeconds > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                remainingSeconds -= 1
                sessionCoordinator.syncRemainingSeconds(remainingSeconds)
            }

            if !Task.isCancelled {
                await completeSession()
            }
        }
    }

    private func executePipeline(videoURL: URL, sessionId: UUID) async {
        guard !Task.isCancelled else { return }

        let child = selectedChild
        setAnalysisProgress(phase: .loadingRecording, fraction: 0.1, detail: "Recording found")

        do {
            let output = try await SessionAnalysisRunner.runPipeline(
                videoURL: videoURL,
                child: child,
                onProgress: { [weak self] progress in
                    Task { @MainActor in
                        self?.analysisProgress = progress
                    }
                }
            )
            guard !Task.isCancelled else { return }
            let result = PipelineResult(from: output)
            sessionAnalysisResult = result
            persistAnalysis(sessionId: sessionId, result: result, errorMessage: nil)
        } catch is CancellationError {
            return
        } catch {
            sessionAnalysisError = error.localizedDescription
            persistAnalysis(sessionId: sessionId, result: nil, errorMessage: error.localizedDescription)
        }
    }

    func cancelSessionAnalysis() {
        postSessionAnalysisTask?.cancel()
        postSessionAnalysisTask = nil
        isAnalyzingSession = false
        analysisProgress = .initial
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

    private func clearAnalysisState() {
        postSessionAnalysisTask?.cancel()
        postSessionAnalysisTask = nil
        isAnalyzingSession = false
        analysisProgress = .initial
        sessionAnalysisResult = nil
        sessionAnalysisError = nil
    }
}
