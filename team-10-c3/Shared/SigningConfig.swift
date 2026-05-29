import Foundation

enum SigningConfig {
    static var appGroupID: String {
        infoPlistString(forKey: "AppGroupIdentifier")
            ?? "group.abui.don-ten-team.shared"
    }

    static var screenRecorderExtensionBundleID: String {
        infoPlistString(forKey: "ScreenRecorderExtensionBundleID")
            ?? "abui.don-ten-team.ScreenRecorderExtension"
    }

    private static func infoPlistString(forKey key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
