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
}
