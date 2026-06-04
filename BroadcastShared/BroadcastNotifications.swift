//
//  BroadcastNotifications.swift
//  Shared between main app and ScreenRecorderExtension
//

import Foundation

/// Darwin notification names used to signal between the app and the broadcast extension.
public enum BroadcastNotifications {
    /// Posted by the extension once the recording file is safely written to the App Group.
    public static var recordingReady: CFNotificationName {
        CFNotificationName("\(BroadcastAppGroup.identifier).recordingReady" as CFString)
    }

    /// Posted by the app to tell the extension to stop recording.
    public static var stopBroadcast: CFNotificationName {
        CFNotificationName("\(BroadcastAppGroup.identifier).stopBroadcast" as CFString)
    }
}
