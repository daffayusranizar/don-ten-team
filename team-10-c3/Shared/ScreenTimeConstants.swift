import Foundation

enum ScreenTimeConstants {
    static var appGroupID: String { SigningConfig.appGroupID }

    static let familySelectionKey = "familyActivitySelection"
    static let sessionShieldActiveKey = "sessionShieldActive"
    static let sessionShieldAllowedKey = "sessionShieldAllowed"
    static let sessionShieldBlockedKey = "sessionShieldBlocked"

    static let sessionActivityName = "parentguide.kid.session"
    static let extensionHeartbeatKey = "deviceActivityExtensionHeartbeat"
}
