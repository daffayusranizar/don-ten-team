import Foundation
import Combine

@MainActor
public class RecordingManager: ObservableObject {
    public static let shared = RecordingManager()
    
    // IMPORTANT: Update this to exactly match the App Group you created in Xcode
    public let appGroupIdentifier = "group.com.team10.c3"
    
    private init() {}
    
    public func fetchLatestRecordedVideoPath() -> String? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return nil }
        return defaults.string(forKey: "LatestRecordingPath")
    }
}
