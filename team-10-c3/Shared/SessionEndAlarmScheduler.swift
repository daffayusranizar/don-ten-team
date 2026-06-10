import Foundation
import ActivityKit
import AlarmKit
import SwiftUI
import UIKit
import UserNotifications

nonisolated struct SessionEndAlarmMetadata: AlarmMetadata, Codable, Sendable {
    var childName: String?
}

/// Schedules session-end alarms via AlarmKit (iOS 26+), with local-notification fallback.
@MainActor
enum SessionEndAlarmScheduler {
    enum AuthorizationDisplayState {
        case notDetermined
        case authorized
        case denied
    }

    static let alarmKitID = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C7450E9D4ED")!
    private static let notificationID = "kiddly.session-end-alarm"

    static var displayState: AuthorizationDisplayState {
        switch AlarmManager.shared.authorizationState {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    static var isAuthorized: Bool {
        displayState == .authorized
    }

    /// User-initiated only — call after showing the in-app permission explainer.
    static func requestAuthorization() async -> AlarmManager.AuthorizationState {
        let manager = AlarmManager.shared
        if manager.authorizationState == .authorized {
            return .authorized
        }
        do {
            let state = try await manager.requestAuthorization()
            BroadcastExtensionLog.append("🔔 AlarmKit authorization requested: \(state)")
            return state
        } catch {
            let detail = Self.describeAuthorizationFailure(error)
            BroadcastExtensionLog.append("⚠️ AlarmKit authorization failed: \(detail)")
            return manager.authorizationState
        }
    }

    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    static func schedule(after seconds: Int, childName: String?) async {
        await cancel()

        guard isAuthorized else {
            BroadcastExtensionLog.append("⚠️ AlarmKit not authorized — session alarm not scheduled")
            return
        }

        let duration = max(1, TimeInterval(seconds))
        let title = alarmTitle(childName: childName)

        do {
            let stopButton = AlarmButton(
                text: "Done",
                textColor: .white,
                systemImageName: "checkmark.circle.fill"
            )
            let alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: title),
                stopButton: stopButton
            )
            let attributes = AlarmAttributes<SessionEndAlarmMetadata>(
                presentation: AlarmPresentation(alert: alert),
                metadata: SessionEndAlarmMetadata(childName: childName),
                tintColor: Color("primaryMediumBlue", bundle: .main)
            )

            let sound = alarmKitSound()
            let fireDate = Date().addingTimeInterval(duration)
            let schedule = Alarm.Schedule.fixed(fireDate)
            let configuration = AlarmManager.AlarmConfiguration<SessionEndAlarmMetadata>.alarm(
                schedule: schedule,
                attributes: attributes,
                sound: sound
            )

            _ = try await AlarmManager.shared.schedule(id: alarmKitID, configuration: configuration)
            let soundName = resolvedBundledAlarmFilename() ?? "default"
            BroadcastExtensionLog.append("🔔 Scheduled AlarmKit session end alarm at \(fireDate) (sound: \(soundName))")
        } catch {
            BroadcastExtensionLog.append("⚠️ AlarmKit schedule failed: \(error.localizedDescription)")
            await scheduleNotificationFallback(after: seconds, childName: childName)
        }
    }

    static func cancel(removeDelivered: Bool = false) async {
        try? AlarmManager.shared.cancel(id: alarmKitID)
        cancelNotification(removeDelivered: removeDelivered)
    }

    // MARK: - Notification fallback

    private static func scheduleNotificationFallback(after seconds: Int, childName: String?) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let isAuthorized: Bool
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
        case .notDetermined:
            guard !PreviewRuntime.isActive else {
                isAuthorized = false
                break
            }
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound])) == true
        case .denied:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
        guard isAuthorized else {
            BroadcastExtensionLog.append("⚠️ Notification fallback not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = alarmTitle(childName: childName)
        content.body = "Screen time has ended."
        content.sound = notificationSound()

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, TimeInterval(seconds)),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
            BroadcastExtensionLog.append("🔔 Scheduled notification fallback alarm in \(max(1, seconds))s")
        } catch {
            BroadcastExtensionLog.append("⚠️ Notification fallback schedule failed: \(error.localizedDescription)")
        }
    }

    private static func cancelNotification(removeDelivered: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        if removeDelivered {
            center.removeDeliveredNotifications(withIdentifiers: [notificationID])
        }
    }

    private static func resolvedBundledAlarmFilename() -> String? {
        if bundledAlarmURL(name: "alarm", ext: "caf") != nil {
            return "alarm.caf"
        }
        if bundledAlarmURL(name: "alarm", ext: "wav") != nil {
            return "alarm.wav"
        }
        return nil
    }

    private static func alarmKitSound() -> ActivityKit.AlertConfiguration.AlertSound {
        if let filename = resolvedBundledAlarmFilename() {
            return .named(filename)
        }
        return .default
    }

    private static func notificationSound() -> UNNotificationSound {
        if let filename = resolvedBundledAlarmFilename() {
            return UNNotificationSound(named: UNNotificationSoundName(filename))
        }
        return .default
    }

    private static func bundledAlarmURL(name: String, ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Resources")
            ?? Bundle.main.url(forResource: name, withExtension: ext)
    }

    private static func describeAuthorizationFailure(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == "com.apple.AlarmKit.Alarm", nsError.code == 1 {
            return "\(error.localizedDescription) (missing NSAlarmKitUsageDescription in app Info.plist)"
        }
        return error.localizedDescription
    }

    private static func alarmTitle(childName: String?) -> String {
        if let childName, !childName.isEmpty {
            return "\(childName)'s session is over"
        }
        return "Session Over"
    }
}
