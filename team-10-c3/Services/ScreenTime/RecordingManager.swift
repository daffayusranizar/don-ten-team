import Foundation
import UIKit
import Combine

/// Snapshot of App Group recordings when a session starts (used to ignore the previous session's file).
public struct RecordingFileSnapshot: Sendable, Equatable {
    public let path: String
    public let fileSize: Int
    public let modifiedAt: Date

    public init(path: String, fileSize: Int, modifiedAt: Date) {
        self.path = path
        self.fileSize = fileSize
        self.modifiedAt = modifiedAt
    }
}

/// Binds post-session polling to one Screen Time session id + start time.
public struct SessionRecordingMatchContext: Sendable {
    public let sessionId: UUID
    public let sessionStartedAt: Date
    public let snapshotsAtStart: [RecordingFileSnapshot]

    public init(sessionId: UUID, sessionStartedAt: Date, snapshotsAtStart: [RecordingFileSnapshot]) {
        self.sessionId = sessionId
        self.sessionStartedAt = sessionStartedAt
        self.snapshotsAtStart = snapshotsAtStart
    }
}

@MainActor
public class RecordingManager: ObservableObject {
    public static let shared = RecordingManager()

    public let appGroupIdentifier = BroadcastConstants.appGroupID

    private static let minimumRecordingBytes = 1000
    private static let grownBytesThreshold = 2048
    private init() {}

    public func fetchLatestRecordedVideoPath() -> String? {
        UserDefaults(suiteName: appGroupIdentifier)?
            .string(forKey: BroadcastStorageKeys.latestRecordingPath)
    }

    // MARK: - Session ↔ recording binding

    /// Call when the user taps Start Session (before ReplayKit confirm) so the extension filenames match the upcoming marker id.
    public func stageRecordingSessionId(_ sessionId: UUID) {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        defaults?.set(sessionId.uuidString.lowercased(), forKey: BroadcastStorageKeys.activeRecordingSessionId)
        defaults?.removeObject(forKey: BroadcastStorageKeys.recordingCompletedSessionId)
        defaults?.synchronize()
    }

    /// Returns a staged id written before broadcast, if any.
    public func consumeStagedRecordingSessionId() -> UUID? {
        guard let raw = UserDefaults(suiteName: appGroupIdentifier)?
            .string(forKey: BroadcastStorageKeys.activeRecordingSessionId) else {
            return nil
        }
        return UUID(uuidString: raw)
    }

    /// Call when a recorded session starts so the extension names the MP4 and completion keys match this id.
    public func bindActiveSessionRecording(
        sessionId: UUID,
        sessionStartedAt: Date
    ) -> SessionRecordingMatchContext {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        defaults?.set(sessionId.uuidString.lowercased(), forKey: BroadcastStorageKeys.activeRecordingSessionId)
        defaults?.removeObject(forKey: BroadcastStorageKeys.recordingCompletedSessionId)
        defaults?.synchronize()

        return SessionRecordingMatchContext(
            sessionId: sessionId,
            sessionStartedAt: sessionStartedAt,
            snapshotsAtStart: snapshotRecordingsInAppGroup()
        )
    }

    public func clearSessionRecordingBinding() {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        defaults?.removeObject(forKey: BroadcastStorageKeys.activeRecordingSessionId)
        defaults?.removeObject(forKey: BroadcastStorageKeys.recordingCompletedSessionId)
        defaults?.synchronize()
    }

    // MARK: - Auto-Stop Session Logic

    public func setSessionDuration(minutes: Int) {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        defaults?.set(minutes, forKey: BroadcastStorageKeys.targetSessionDurationMinutes)
        defaults?.synchronize()
    }

    public func clearSessionDuration() {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        defaults?.removeObject(forKey: BroadcastStorageKeys.targetSessionDurationMinutes)
        defaults?.synchronize()
    }

    public func clearBroadcastActiveFlag() {
        guard !BroadcastCaptureStatus.isCaptureInProgress else { return }
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        defaults?.set(false, forKey: BroadcastStorageKeys.broadcastActive)
        defaults?.synchronize()
    }

    public func postStopBroadcast() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            BroadcastConstants.stopBroadcastNotification,
            nil, nil, true
        )
    }

    public func waitForBroadcastEnded(timeout: TimeInterval = 8) async {
        let deadline = Date().addingTimeInterval(timeout)
        while BroadcastCaptureStatus.isReplayKitBroadcastActive, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    /// Polls until an MP4 matches `context` (not the previous session's "latest" file).
    public func pollForSessionRecording(
        context: SessionRecordingMatchContext,
        timeout: TimeInterval = 90,
        interval: TimeInterval = 0.5
    ) async -> URL? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if Task.isCancelled { return nil }
            if let url = findRecordingMatchingSession(context) {
                return url
            }
            try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))
        }
        return findRecordingMatchingSession(context)
    }

    // MARK: - Session matching

    /// Finds the MP4 for this session using completion keys, bound filename, then baseline diff.
    public func findRecordingMatchingSession(_ context: SessionRecordingMatchContext) -> URL? {
        let sessionKey = context.sessionId.uuidString.lowercased()
        let defaults = UserDefaults(suiteName: appGroupIdentifier)

        if let completedId = defaults?.string(forKey: BroadcastStorageKeys.recordingCompletedSessionId),
           completedId.lowercased() == sessionKey,
           let path = defaults?.string(forKey: BroadcastStorageKeys.latestRecordingPath) {
            let url = URL(fileURLWithPath: path)
            if isValidRecording(url) { return url }
        }

        if let container = appGroupContainerURL() {
            let boundURL = container.appendingPathComponent(SessionRecordingFilename.mp4Name(sessionId: context.sessionId))
            if isValidRecording(boundURL) { return boundURL }
        }

        let baselineByPath = Dictionary(
            uniqueKeysWithValues: context.snapshotsAtStart.map { ($0.path, $0) }
        )
        let candidates = listValidRecordingsInAppGroup()
            .sorted { $0.modifiedAt > $1.modifiedAt }

        for snap in candidates {
            let url = URL(fileURLWithPath: snap.path)

            if let baseline = baselineByPath[snap.path] {
                let grown = snap.fileSize > baseline.fileSize + Self.grownBytesThreshold
                let modifiedAfterStart = snap.modifiedAt > context.sessionStartedAt
                if grown && modifiedAfterStart {
                    return url
                }
                continue
            }

            if snap.modifiedAt >= context.sessionStartedAt.addingTimeInterval(-1) {
                return url
            }
        }

        return nil
    }

    // MARK: - Recording File Lookup

    public func findLatestRecordingURL() -> URL? {
        listValidRecordingsInAppGroup()
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .first
            .map { URL(fileURLWithPath: $0.path) }
    }

    public func findValidRecordingURL() -> URL? {
        guard let url = findLatestRecordingURL() else { return nil }
        return isValidRecording(url) ? url : nil
    }

    private func snapshotRecordingsInAppGroup() -> [RecordingFileSnapshot] {
        listValidRecordingsInAppGroup()
    }

    private func listValidRecordingsInAppGroup() -> [RecordingFileSnapshot] {
        guard let container = appGroupContainerURL() else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: container,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: []
        )) ?? []

        return files
            .filter { $0.pathExtension == "mp4" }
            .compactMap { url -> RecordingFileSnapshot? in
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                let size = values?.fileSize ?? 0
                guard size > Self.minimumRecordingBytes else { return nil }
                return RecordingFileSnapshot(
                    path: url.path,
                    fileSize: size,
                    modifiedAt: values?.contentModificationDate ?? .distantPast
                )
            }
    }

    private func appGroupContainerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private func isValidRecording(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return size > Self.minimumRecordingBytes
    }
}
