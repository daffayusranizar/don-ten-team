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

/// Re-fires the extension's Darwin `sessionTimerFired` signal as a NotificationCenter event.
enum SessionTimerFiredBridge {
    static let notification = Notification.Name("SessionTimerFiredInternalNotification")
    private static var isDarwinObserverRegistered = false

    static func ensureListening() {
        guard !isDarwinObserverRegistered else { return }
        isDarwinObserverRegistered = true

        let darwinName = "\(BroadcastAppGroup.identifier).sessionTimerFired" as CFString
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: SessionTimerFiredBridge.notification, object: nil)
                }
            },
            darwinName,
            nil,
            .deliverImmediately
        )
    }
}
