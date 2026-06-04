import Foundation

/// Re-fires the extension's Darwin `recordingReady` signal as a NotificationCenter event for SwiftUI.
enum RecordingReadyBridge {
    static let notification = Notification.Name("RecordingReadyInternalNotification")
    private static var isDarwinObserverRegistered = false

    /// Registers the Darwin observer once (call at app launch and before stopping broadcast).
    static func ensureListening() {
        guard !isDarwinObserverRegistered else { return }
        isDarwinObserverRegistered = true

        let darwinName = "\(BroadcastAppGroup.identifier).recordingReady" as CFString
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: RecordingReadyBridge.notification, object: nil)
                }
            },
            darwinName,
            nil,
            .deliverImmediately
        )
    }

    static func startListening() {
        ensureListening()
    }
}
