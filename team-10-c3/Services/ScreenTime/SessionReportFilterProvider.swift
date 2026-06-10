import DeviceActivity
import FamilyControls
import Foundation

enum SessionReportFilterProvider {
    static func todayReportFilter(
        childId: UUID,
        day: Date,
        sessionRepository: SessionRepository,
        activeSession: ActiveSessionInfo? = nil,
        referenceNow: Date = Date(),
        calendar: Calendar = .current
    ) -> DeviceActivityFilter? {
        let apps = FamilyActivitySelectionStore.allowedApplicationTokensForShields()
        let windows = sessionWindows(
            childId: childId,
            days: [calendar.startOfDay(for: day)],
            sessionRepository: sessionRepository,
            activeSession: activeSession,
            referenceNow: referenceNow,
            calendar: calendar
        )
        return SessionReportFilterBuilder.todaySessionsFilter(windows: windows, applications: apps)
    }

    static func weekReportFilter(
        childId: UUID,
        referenceDate: Date = Date(),
        sessionRepository: SessionRepository,
        activeSession: ActiveSessionInfo? = nil,
        referenceNow: Date = Date(),
        calendar: Calendar = .current
    ) -> DeviceActivityFilter? {
        let apps = FamilyActivitySelectionStore.allowedApplicationTokensForShields()
        let days = weekDays(for: referenceDate, calendar: calendar)
        let windows = sessionWindows(
            childId: childId,
            days: days,
            sessionRepository: sessionRepository,
            activeSession: activeSession,
            referenceNow: referenceNow,
            calendar: calendar
        )
        return SessionReportFilterBuilder.weekSessionsFilter(windows: windows, applications: apps)
    }

    private static func sessionWindows(
        childId: UUID,
        days: [Date],
        sessionRepository: SessionRepository,
        activeSession: ActiveSessionInfo?,
        referenceNow: Date,
        calendar: Calendar
    ) -> [SessionReportTimeWindow] {
        var windows: [SessionReportTimeWindow] = []
        for day in days {
            if let completed = try? sessionRepository.completedSessionWindows(for: childId, day: day),
               !completed.isEmpty {
                windows.append(contentsOf: completed.map(Self.timeWindow(from:)))
            } else if let snapshots = try? sessionRepository.snapshots(for: childId, on: day) {
                windows.append(contentsOf: snapshots.map {
                    SessionReportTimeWindow(startAt: $0.startAt, stopAt: $0.stopAt)
                })
            }
        }

        let resolvedActive = activeSession ?? (try? sessionRepository.activeSession(for: childId))
        if let active = resolvedActive,
           active.childId == childId,
           days.contains(where: { calendar.isDate(active.startedAt, inSameDayAs: $0) }) {
            windows.append(SessionReportTimeWindow(startAt: active.startedAt, stopAt: referenceNow))
        }

        return windows
    }

    private static func timeWindow(from window: SessionWindow) -> SessionReportTimeWindow {
        SessionReportTimeWindow(startAt: window.startAt, stopAt: window.stopAt)
    }

    private static func weekDays(for referenceDate: Date, calendar: Calendar) -> [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return [calendar.startOfDay(for: referenceDate)]
        }
        var days: [Date] = []
        var cursor = interval.start
        while cursor < interval.end {
            days.append(calendar.startOfDay(for: cursor))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }
}
