import Foundation

enum ScreenTimeConstants {
    static let appGroupID = "group.abui.don-ten-team.shared"

    static let queryChildIdKey = "sessionUsageQueryChildId"
    static let queryStartKey = "sessionUsageQueryStart"
    static let queryEndKey = "sessionUsageQueryEnd"
    static let usagePayloadKey = "sessionUsagePayloadJSON"

    static let usageReadyNotification = CFNotificationName(
        "com.team10.c3.sessionUsageReady" as CFString
    )
}

struct AppUsageRow: Codable, Sendable, Equatable {
    let displayName: String
    let bundleIdentifier: String
    let durationSeconds: Int
}

struct SessionUsagePayload: Codable, Sendable, Equatable {
    let childId: UUID
    let startAt: Date
    let stopAt: Date
    let totalSeconds: Int
    let apps: [AppUsageRow]

    static func encodeJSON(_ payload: SessionUsagePayload) -> String? {
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
