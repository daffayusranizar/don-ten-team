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
}
