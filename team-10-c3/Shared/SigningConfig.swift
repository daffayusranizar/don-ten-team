import Foundation

enum SigningConfig {
    static var appGroupID: String {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return "group.abui.don-ten-team.shared"
        }
        let prefix = bundleID.components(separatedBy: ".").first ?? "abui"
        return "group.\(prefix).don-ten-team.shared"
    }

    static var screenRecorderExtensionBundleID: String {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return "abui.don-ten-team.ScreenRecorderExtension"
        }
        let prefix = bundleID.components(separatedBy: ".").first ?? "abui"
        return "\(prefix).don-ten-team.ScreenRecorderExtension"
    }

}
