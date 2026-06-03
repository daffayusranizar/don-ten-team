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

    var selectedChild: Child?
    var isSessionActive = false
    var isSessionComplete = false
    var remainingSeconds = 0
    /// Set when the session was started with screen recording enabled.
    var sessionIncludedScreenRecording = false

    var isAnalyzingSession = false
    var analysisProgress = SessionAnalysisProgress.initial
    var sessionAnalysisResult: PipelineResult?
    var sessionAnalysisError: String?

    private var timerTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?

    let durationOptions: [Int]

    init(
        sessionCoordinator: SessionCoordinator,
        durationOptions: [Int] = [15, 30, 45, 60]
    ) {
        self.sessionCoordinator = sessionCoordinator
        self.durationOptions = durationOptions
    }

    var durationMinutes: Int {
        get { sessionCoordinator.durationMinutes }
        set { sessionCoordinator.durationMinutes = newValue }
    }

    var formattedRemainingTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var canStartSession: Bool {
        selectedChild != nil && !isSessionActive
    }

    func syncSelectedChild(from profileViewModel: ProfileViewModel) {
        selectedChild = profileViewModel.selectedChild
    }

    /// Branch runtime: local countdown + recording stop signal; Screen Time prep without coordinator timer.
    func startSession(includesScreenRecording: Bool = false) {
        guard let child = selectedChild else { return }
        guard !isSessionActive else { return }

        sessionIncludedScreenRecording = includesScreenRecording
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
            startBranchTimer()
        }
    }

    func endSessionEarly() {
        timerTask?.cancel()
        if UIScreen.main.isCaptured {
            RecordingManager.shared.postStopBroadcast()
        }
        Task { await finishAndPersistSession() }
    }

    func resetAfterEndScreen() {
        cancelSessionAnalysis()
        isSessionComplete = false
        sessionIncludedScreenRecording = false
        clearAnalysisState()
        sessionCoordinator.resetAfterEndScreen()
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
                await finishAndPersistSession()
            }
        }
    }

    /// Main persistence: markers, timer snapshot, Screen Time enrichment; then AI analysis if recorded.
    private func finishAndPersistSession() async {
        guard isSessionActive else { return }
        timerTask?.cancel()
        isSessionActive = false
        remainingSeconds = 0
        sessionCoordinator.syncRemainingSeconds(0)

        await sessionCoordinator.stopSession()
        isSessionComplete = true

        if sessionIncludedScreenRecording {
            analysisTask?.cancel()
            analysisTask = Task { await runSessionAnalysis() }
        }
    }

    private func runSessionAnalysis() async {
        isAnalyzingSession = true
        analysisProgress = .initial
        sessionAnalysisResult = nil
        sessionAnalysisError = nil
        defer { isAnalyzingSession = false }

        guard !Task.isCancelled else { return }

        RecordingReadyBridge.startListening()
        setAnalysisProgress(phase: .waitingForRecording, fraction: 0.02, detail: "Waiting for broadcast to finish…")
        _ = await waitForRecordingReady(timeoutSeconds: 10)

        guard !Task.isCancelled else { return }

        await executePipeline()
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

    private func waitForRecordingReady(timeoutSeconds: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            var observer: NSObjectProtocol?
            var finished = false

            let complete: (Bool) -> Void = { value in
                guard !finished else { return }
                finished = true
                if let observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                continuation.resume(returning: value)
            }

            observer = NotificationCenter.default.addObserver(
                forName: RecordingReadyBridge.notification,
                object: nil,
                queue: .main
            ) { _ in
                complete(true)
            }

            Task {
                try? await Task.sleep(for: .seconds(timeoutSeconds))
                complete(false)
            }
        }
    }

    private func executePipeline() async {
        let recordingManager = RecordingManager.shared
        let child = selectedChild

        setAnalysisProgress(phase: .loadingRecording, fraction: 0.06, detail: "Looking for the saved video…")

        guard let videoURL = await waitForRecordingFileWithProgress(recordingManager: recordingManager) else {
            sessionAnalysisError =
                "No recording found in App Group '\(recordingManager.appGroupIdentifier)'. " +
                "Make sure you started the ScreenRecorder broadcast and kept it running during the session."
            return
        }

        guard !Task.isCancelled else { return }

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
            sessionAnalysisResult = PipelineResult(from: output)
        } catch is CancellationError {
            return
        } catch {
            sessionAnalysisError = error.localizedDescription
        }
    }

    /// Stops analysis UI and cancels in-flight pipeline work.
    func cancelSessionAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
        isAnalyzingSession = false
        analysisProgress = .initial
    }

    @MainActor
    private func waitForRecordingFileWithProgress(
        recordingManager: RecordingManager
    ) async -> URL? {
        let maxAttempts = SessionAnalysisRunner.recordingFilePollAttempts
        for attempt in 0..<maxAttempts {
            if Task.isCancelled { return nil }
            if let url = recordingManager.findLatestRecordingURL() {
                setAnalysisProgress(phase: .loadingRecording, fraction: 0.1, detail: "Recording found")
                return url
            }
            let pollFraction = 0.06 + (0.04 * Double(attempt + 1) / Double(maxAttempts))
            setAnalysisProgress(
                phase: .loadingRecording,
                fraction: pollFraction,
                detail: "Waiting for file… (\(attempt + 1)/\(maxAttempts))"
            )
            if attempt < maxAttempts - 1 {
                try? await Task.sleep(for: .seconds(SessionAnalysisRunner.recordingFilePollIntervalSeconds))
            }
        }
        return recordingManager.findLatestRecordingURL()
    }

    /// Clears in-memory AI results; screen-by-screen breakdown is only available until this runs.
    private func clearAnalysisState() {
        isAnalyzingSession = false
        analysisProgress = .initial
        sessionAnalysisResult = nil
        sessionAnalysisError = nil
    }
}
