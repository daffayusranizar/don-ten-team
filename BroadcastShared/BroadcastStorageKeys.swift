//
//  BroadcastStorageKeys.swift
//  Shared between main app and ScreenRecorderExtension
//

import Foundation

/// App Group UserDefaults keys and filenames shared by the app and the broadcast extension.
public enum BroadcastStorageKeys {
    /// Path of the latest recording MP4 that the extension wrote.
    public static let latestRecordingPath = "LatestRecordingPath"

    /// Start-marker UUID for the app session the next/current broadcast belongs to.
    public static let activeRecordingSessionId = "ActiveRecordingSessionId"

    /// Set when the extension finishes writing the MP4 for that session id.
    public static let recordingCompletedSessionId = "RecordingCompletedSessionId"

    /// Session duration in minutes, read by the extension for its auto-stop timer.
    public static let targetSessionDurationMinutes = "TargetSessionDurationMinutes"

    /// Set to `true` when the extension starts, `false` when it finishes.
    public static let broadcastActive = "broadcastActive"

    /// Filename of the extension's diagnostic log inside the App Group container.
    public static let extensionDebugLog = "extension_debug.log"
}
