//
//  BroadcastCaptureStatus.swift
//  team-10-c3
//

import UIKit

/// Screen-capture detection for ReplayKit sessions.
enum BroadcastCaptureStatus {

    static var isMainScreenCaptured: Bool {
        UIScreen.main.isCaptured
    }

    /// External monitors often set `isCaptured` on the mirrored screen without ReplayKit.
    static var isExternalScreenCaptured: Bool {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            if windowScene.screen !== UIScreen.main, windowScene.screen.isCaptured {
                return true
            }
        }
        return false
    }

    /// True when ReplayKit reports capture on any connected display.
    static var isAnyScreenCaptured: Bool {
        isMainScreenCaptured || isExternalScreenCaptured
    }

    /// Extension wrote `broadcastActive` in the App Group.
    static var isExtensionBroadcastActive: Bool {
        UserDefaults(suiteName: BroadcastAppGroup.identifier)?
            .bool(forKey: BroadcastStorageKeys.broadcastActive) ?? false
    }

    /// After the user tapped Start and confirmed broadcast — safe to open the active session screen.
    /// Ignores external-screen `isCaptured` alone (Lightning/HDMI mirror false positive).
    static var isBroadcastConfirmedForSessionStart: Bool {
        isMainScreenCaptured || isExtensionBroadcastActive
    }

    /// ReplayKit broadcast is live (ignores external-monitor mirror `isCaptured` alone).
    static var isReplayKitBroadcastActive: Bool {
        isMainScreenCaptured || isExtensionBroadcastActive
    }

    /// Broad check for UI warnings (includes mirrored external display).
    static var isCaptureInProgress: Bool {
        isAnyScreenCaptured || isExtensionBroadcastActive
    }
}
