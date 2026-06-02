import Foundation

enum SessionUsagePayloadWriter {
    static var appGroupID: String {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
            ?? ScreenTimeConstants.appGroupID
    }

    static func write(_ payload: SessionUsagePayload) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let json = SessionUsagePayload.encodeJSON(payload) else {
            return
        }
        defaults.set(json, forKey: ScreenTimeConstants.usagePayloadKey)
        defaults.synchronize()
        postReadyNotification()
    }

    static func writeFromAppGroup() {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let childIdString = defaults.string(forKey: ScreenTimeConstants.queryChildIdKey),
              let childId = UUID(uuidString: childIdString) else {
            return
        }

        let startAt = Date(timeIntervalSince1970: defaults.double(forKey: ScreenTimeConstants.queryStartKey))
        let stopAt = Date(timeIntervalSince1970: defaults.double(forKey: ScreenTimeConstants.queryEndKey))
        guard stopAt > startAt else { return }

        let duration = max(60, Int(stopAt.timeIntervalSince(startAt)))
        let payload = SessionUsagePayload(
            childId: childId,
            startAt: startAt,
            stopAt: stopAt,
            totalSeconds: duration,
            apps: [
                AppUsageRow(displayName: "YouTube", bundleIdentifier: "com.google.ios.youtube", durationSeconds: duration * 45 / 100),
                AppUsageRow(displayName: "TikTok", bundleIdentifier: "com.zhiliaoapp.musically", durationSeconds: duration * 30 / 100),
                AppUsageRow(displayName: "Games", bundleIdentifier: "com.apple.game", durationSeconds: duration * 25 / 100)
            ]
        )
        write(payload)
    }

    private static func postReadyNotification() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            ScreenTimeConstants.usageReadyNotification,
            nil,
            nil,
            true
        )
    }
}
