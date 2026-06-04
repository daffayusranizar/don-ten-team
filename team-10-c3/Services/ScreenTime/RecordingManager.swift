import Foundation
import UIKit
import Combine

@MainActor
public class RecordingManager: ObservableObject {
    public static let shared = RecordingManager()

    public let appGroupIdentifier = BroadcastConstants.appGroupID

    private init() {}

    public func fetchLatestRecordedVideoPath() -> String? {
        UserDefaults(suiteName: appGroupIdentifier)?
            .string(forKey: BroadcastStorageKeys.latestRecordingPath)
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

    /// Clears `broadcastActive` only when nothing is capturing (safe after a session ends).
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

    // MARK: - Broadcast Teardown Wait

    /// Polls `UIScreen.main.isCaptured` until the broadcast ends or `timeout` elapses.
    /// Call this before starting analysis to avoid a race between the extension finalizing
    /// the recording and the app trying to read it.
    /// Waits until ReplayKit teardown finishes. Does not wait on external-display mirror `isCaptured`.
    public func waitForBroadcastEnded(timeout: TimeInterval = 8) async {
        let deadline = Date().addingTimeInterval(timeout)
        while BroadcastCaptureStatus.isReplayKitBroadcastActive, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    // MARK: - Recording File Lookup

    public func findLatestRecordingURL() -> URL? {
        let fileManager = FileManager.default
        if let path = fetchLatestRecordedVideoPath() {
            let url = URL(fileURLWithPath: path)
            if fileManager.fileExists(atPath: url.path) { return url }
        }
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return nil }

        let files = (try? fileManager.contentsOfDirectory(
            at: container,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: []
        )) ?? []

        return files
            .filter { $0.pathExtension == "mp4" }
            .filter { (try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0 > 1000 }
            .sorted {
                let date0 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let date1 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return date0 > date1
            }
            .first
    }
}
