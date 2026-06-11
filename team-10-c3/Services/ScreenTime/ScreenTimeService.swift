import Foundation
import DeviceActivity
import FamilyControls

@MainActor
protocol ScreenTimeUsageProviding {
    func activateSessionRestrictions() async throws
    func deactivateSessionRestrictions()
    func startMonitoring(childId: UUID, startAt: Date, plannedEndAt: Date) throws
    func stopMonitoring() throws
}

@MainActor
final class ScreenTimeService: ScreenTimeUsageProviding {
    private let center = DeviceActivityCenter()
    private let activityName = DeviceActivityName(ScreenTimeConstants.sessionActivityName)

    func activateSessionRestrictions() async throws {
        try await SessionAppShield.applyAllowlist()
    }

    func deactivateSessionRestrictions() {
        SessionAppShield.clear()
    }

    func startMonitoring(childId: UUID, startAt: Date, plannedEndAt: Date) throws {
        let monitoringEnd = monitoringIntervalEnd(startAt: startAt, plannedEndAt: plannedEndAt)
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents.from(date: startAt),
            intervalEnd: DateComponents.from(date: monitoringEnd),
            repeats: false
        )

        try center.startMonitoring(activityName, during: schedule)
        SessionShieldStore.applyFromAppGroupIfActive()
    }

    /// Apple requires ≥15 minutes on the activity schedule; the parent timer may still end sooner.
    private func monitoringIntervalEnd(startAt: Date, plannedEndAt: Date) -> Date {
        let minimumEnd = startAt.addingTimeInterval(
            TimeInterval(SessionDurationLimits.minimumMonitoringSeconds)
        )
        return max(plannedEndAt, minimumEnd)
    }

    func stopMonitoring() throws {
        center.stopMonitoring([activityName])
    }
}

private extension DateComponents {
    static func from(date: Date, calendar: Calendar = .current) -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }
}
