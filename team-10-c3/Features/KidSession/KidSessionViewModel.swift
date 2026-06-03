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
        analysisTask?.cancel()
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
        sessionAnalysisResult = nil
        sessionAnalysisError = nil

        RecordingReadyBridge.startListening()
        _ = await waitForRecordingReady(timeoutSeconds: 10)
        await executePipeline()

        isAnalyzingSession = false
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
        guard let videoURL = recordingManager.findLatestRecordingURL() else {
            sessionAnalysisError =
                "No recording found in App Group '\(recordingManager.appGroupIdentifier)'. " +
                "Make sure you started the ScreenRecorder broadcast and kept it running during the session."
            return
        }
        do {
            let orchestrator = PipelineOrchestrator()
            let output = try await orchestrator.processSession(videoURL: videoURL)
            sessionAnalysisResult = PipelineResult(from: output)
        } catch {
            sessionAnalysisError = error.localizedDescription
        }
    }

    private func clearAnalysisState() {
        isAnalyzingSession = false
        sessionAnalysisResult = nil
        sessionAnalysisError = nil
    }
}
