import Foundation

enum ScreenTimeConstants {
    static var appGroupID: String { SigningConfig.appGroupID }

    static let queryChildIdKey = "sessionUsageQueryChildId"
    static let queryStartKey = "sessionUsageQueryStart"
    static let queryEndKey = "sessionUsageQueryEnd"
    static let usagePayloadKey = "sessionUsagePayloadJSON"
    static let familySelectionKey = "familyActivitySelection"
    static let sessionShieldActiveKey = "sessionShieldActive"
    static let sessionShieldAllowedKey = "sessionShieldAllowed"
    static let sessionShieldBlockedKey = "sessionShieldBlocked"

    static let usageReadyNotification = CFNotificationName(
        "com.team10.c3.sessionUsageReady" as CFString
    )

    static let sessionActivityName = "parentguide.kid.session"
    static let extensionHeartbeatKey = "deviceActivityExtensionHeartbeat"
}
