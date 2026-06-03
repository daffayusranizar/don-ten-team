import Foundation
import Combine

@MainActor
public class RecordingManager: ObservableObject {
    public static let shared = RecordingManager()
    
    public let appGroupIdentifier = BroadcastConstants.appGroupID
    
    private init() {}
    
    public func fetchLatestRecordedVideoPath() -> String? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return nil }
        return defaults.string(forKey: "LatestRecordingPath")
    }
    
    // MARK: - Auto-Stop Session Logic
    public func setSessionDuration(minutes: Int) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        defaults.set(minutes, forKey: "TargetSessionDurationMinutes")
        defaults.synchronize()
    }
    
    public func clearSessionDuration() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        defaults.removeObject(forKey: "TargetSessionDurationMinutes")
        defaults.synchronize()
    }

    public func postStopBroadcast() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            BroadcastConstants.stopBroadcastNotification,
            nil, nil, true
        )
    }

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
                let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return d1 > d2
            }
            .first
    }
}
