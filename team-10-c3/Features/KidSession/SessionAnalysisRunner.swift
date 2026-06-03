//
//  SessionAnalysisRunner.swift
//  team-10-c3
//

import Foundation

enum SessionAnalysisRunner {
    static let pipelineTimeoutSeconds: UInt64 = 600
    static let recordingFilePollAttempts = 20
    static let recordingFilePollIntervalSeconds: UInt64 = 1

    struct TimedOut: LocalizedError {
        var errorDescription: String? {
            "Analysis took too long and was stopped. You can start a new session and try again with a shorter recording."
        }
    }

    @MainActor
    static func waitForRecordingFile(
        recordingManager: RecordingManager,
        maxAttempts: Int = recordingFilePollAttempts,
        intervalSeconds: UInt64 = recordingFilePollIntervalSeconds
    ) async -> URL? {
        for attempt in 0..<maxAttempts {
            if Task.isCancelled { return nil }
            if let url = recordingManager.findLatestRecordingURL() {
                return url
            }
            if attempt < maxAttempts - 1 {
                try? await Task.sleep(for: .seconds(intervalSeconds))
            }
        }
        return recordingManager.findLatestRecordingURL()
    }

    static func runPipeline(
        videoURL: URL,
        child: Child?,
        timeoutSeconds: UInt64 = pipelineTimeoutSeconds,
        onProgress: SessionAnalysisProgressHandler? = nil
    ) async throws -> SessionAnalysisResult {
        let orchestrator = PipelineOrchestrator()
        return try await withTimeout(seconds: timeoutSeconds) {
            try await orchestrator.processSession(
                videoURL: videoURL,
                child: child,
                onProgress: onProgress
            )
        }
    }

    private static func withTimeout<T: Sendable>(
        seconds: UInt64,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TimedOut()
            }
            guard let value = try await group.next() else {
                throw TimedOut()
            }
            group.cancelAll()
            return value
        }
    }
}
