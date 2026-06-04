//
//  BroadcastAppGroup.swift
//  Shared between main app and ScreenRecorderExtension
//

import Foundation

/// Single source of truth for the shared app group identifier.
/// Works from both the main app bundle and the extension bundle because both
/// use a prefix-based bundle ID (`<prefix>.don-ten-team` / `<prefix>.don-ten-team.ScreenRecorderExtension`).
public enum BroadcastAppGroup {
    public static var identifier: String {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return "group.abui.don-ten-team.shared"
        }
        let prefix = bundleID.components(separatedBy: ".").first ?? "abui"
        return "group.\(prefix).don-ten-team.shared"
    }
}
