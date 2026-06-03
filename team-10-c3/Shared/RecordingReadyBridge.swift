import Foundation

/// Re-fires the extension's Darwin `recordingReady` signal as a NotificationCenter event for SwiftUI.
enum RecordingReadyBridge {
    static let notification = Notification.Name("RecordingReadyInternalNotification")

    static func startListening() {
        let appGroupID = BroadcastConstants.appGroupID
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: RecordingReadyBridge.notification, object: nil)
                }
            },
            "\(appGroupID).recordingReady" as CFString,
            nil,
            .deliverImmediately
        )
    }
}
