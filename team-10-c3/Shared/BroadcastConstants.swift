//
//  BroadcastConstants.swift
//  Shared between main app and Broadcast Upload Extension
//

import Foundation

public enum BroadcastConstants {
    static var appGroupID: String { SigningConfig.appGroupID }
    static let recordingsFolderName = "Recordings"

    /// Frames written to the saved MP4 during broadcast (1 frame per second).
    static let targetRecordingFPS: Double = 1

    /// Classify one saved frame every N seconds during post-processing.
    public static let classificationIntervalSeconds: Int = 2

    static let recordingReadyKey = "recordingReady"
    static let lastRecordingPathKey = "lastRecordingPath"
    static let recordingFinishedAtKey = "recordingFinishedAt"
    static let broadcastActiveKey = "broadcastActive"

    static var recordingReadyNotification: CFNotificationName { BroadcastNotifications.recordingReady }
    static var stopBroadcastNotification: CFNotificationName { BroadcastNotifications.stopBroadcast }

    static var latestRecordingPathKey: String { BroadcastStorageKeys.latestRecordingPath }
    static var targetSessionDurationKey: String { BroadcastStorageKeys.targetSessionDurationMinutes }

    /// Shown in the system screen-recording picker when the parent starts a session.
    static let extensionDisplayName = "Kiddly"

    /// Fallback if the embedded plug-in cannot be discovered at runtime.
    static var fallbackExtensionBundleID: String { SigningConfig.screenRecorderExtensionBundleID }

    /// Bundle ID of the embedded Broadcast Upload Extension inside the app.
    static var extensionBundleID: String {
        resolvedExtensionBundleID ?? fallbackExtensionBundleID
    }

    static var resolvedExtensionBundleID: String? {
        guard let pluginsURL = Bundle.main.builtInPlugInsURL,
              let contents = try? FileManager.default.contentsOfDirectory(
                at: pluginsURL,
                includingPropertiesForKeys: nil
              ) else {
            return nil
        }

        let extensionBundleIDs = contents
            .filter { $0.pathExtension == "appex" }
            .compactMap { Bundle(url: $0)?.bundleIdentifier }

        return extensionBundleIDs.first { $0 == fallbackExtensionBundleID }
            ?? extensionBundleIDs.first { $0.hasSuffix(".ScreenRecorderExtension") }
    }

    static var isExtensionEmbedded: Bool {
        resolvedExtensionBundleID != nil
    }
}
