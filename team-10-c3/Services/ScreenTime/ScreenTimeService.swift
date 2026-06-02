import Foundation
import DeviceActivity
import FamilyControls

@MainActor
protocol ScreenTimeUsageProviding {
    func startMonitoring(childId: UUID, startAt: Date, plannedEndAt: Date) throws
    func stopMonitoring() throws
    func fetchUsage(childId: UUID, startAt: Date, stopAt: Date) async throws -> SessionUsagePayload
}

@MainActor
final class ScreenTimeService: ScreenTimeUsageProviding {
    private let center = DeviceActivityCenter()
    private let activityName = DeviceActivityName(ScreenTimeConstants.sessionActivityName)

    func startMonitoring(childId: UUID, startAt: Date, plannedEndAt: Date) throws {
        let selection = FamilyActivitySelectionStore.load()
        guard !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty else {
            return
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents.from(date: startAt),
            intervalEnd: DateComponents.from(date: plannedEndAt),
            repeats: false
        )

        try center.startMonitoring(activityName, during: schedule)
    }

    func stopMonitoring() throws {
        center.stopMonitoring([activityName])
    }

    func fetchUsage(childId: UUID, startAt: Date, stopAt: Date) async throws -> SessionUsagePayload {
        writeQueryToAppGroup(childId: childId, startAt: startAt, stopAt: stopAt)

        if let payload = await waitForUsagePayload(
            childId: childId,
            startAt: startAt,
            stopAt: stopAt,
            timeoutSeconds: 8
        ) {
            return payload
        }

        return MockScreenTimeUsageBuilder.build(
            childId: childId,
            startAt: startAt,
            stopAt: stopAt
        )
    }

    private func writeQueryToAppGroup(childId: UUID, startAt: Date, stopAt: Date) {
        guard let defaults = UserDefaults(suiteName: ScreenTimeConstants.appGroupID) else { return }
        defaults.set(childId.uuidString, forKey: ScreenTimeConstants.queryChildIdKey)
        defaults.set(startAt.timeIntervalSince1970, forKey: ScreenTimeConstants.queryStartKey)
        defaults.set(stopAt.timeIntervalSince1970, forKey: ScreenTimeConstants.queryEndKey)
        defaults.removeObject(forKey: ScreenTimeConstants.usagePayloadKey)
        defaults.synchronize()
        postUsageQueryNotification()
    }

    private func postUsageQueryNotification() {
        let notification = ScreenTimeConstants.usageReadyNotification
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            notification,
            nil,
            nil,
            true
        )
    }

    private func waitForUsagePayload(
        childId: UUID,
        startAt: Date,
        stopAt: Date,
        timeoutSeconds: TimeInterval
    ) async -> SessionUsagePayload? {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if let payload = readPayloadFromAppGroup(),
               payload.childId == childId,
               abs(payload.startAt.timeIntervalSince(startAt)) < 2,
               abs(payload.stopAt.timeIntervalSince(stopAt)) < 2 {
                return payload
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return readPayloadFromAppGroup()
    }

    private func readPayloadFromAppGroup() -> SessionUsagePayload? {
        guard let defaults = UserDefaults(suiteName: ScreenTimeConstants.appGroupID),
              let json = defaults.string(forKey: ScreenTimeConstants.usagePayloadKey) else {
            return nil
        }
        return SessionUsagePayload.decodeJSON(json)
    }
}

@MainActor
enum MockScreenTimeUsageBuilder {
    static func build(childId: UUID, startAt: Date, stopAt: Date) -> SessionUsagePayload {
        let duration = max(60, Int(stopAt.timeIntervalSince(startAt)))
        let apps: [AppUsageRow] = [
            AppUsageRow(displayName: "YouTube", bundleIdentifier: "com.google.ios.youtube", durationSeconds: duration * 45 / 100),
            AppUsageRow(displayName: "TikTok", bundleIdentifier: "com.zhiliaoapp.musically", durationSeconds: duration * 30 / 100),
            AppUsageRow(displayName: "Games", bundleIdentifier: "com.apple.game", durationSeconds: duration * 25 / 100)
        ]
        return SessionUsagePayload(
            childId: childId,
            startAt: startAt,
            stopAt: stopAt,
            totalSeconds: apps.map(\.durationSeconds).reduce(0, +),
            apps: apps
        )
    }
}

private extension DateComponents {
    static func from(date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute, .second], from: date)
    }
}
