import Foundation

enum SigningConfig {
    static var appGroupID: String { BroadcastAppGroup.identifier }

    static var screenRecorderExtensionBundleID: String {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return "abui.don-ten-team.ScreenRecorderExtension"
        }
        let prefix = bundleID.components(separatedBy: ".").first ?? "abui"
        return "\(prefix).don-ten-team.ScreenRecorderExtension"
    }

}
