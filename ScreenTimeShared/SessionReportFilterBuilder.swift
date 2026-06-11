import DeviceActivity
import Foundation
import ManagedSettings

struct SessionReportTimeWindow: Sendable, Equatable {
    let startAt: Date
    let stopAt: Date
}

enum SessionReportFilterBuilder {
    static func todayFilter(
        referenceDate: Date = Date(),
        applications: Set<ApplicationToken> = [],
        calendar: Calendar = .current
    ) -> DeviceActivityFilter {
        let dayStart = calendar.startOfDay(for: referenceDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? referenceDate
        let interval = DateInterval(start: dayStart, end: dayEnd)
        return makeFilter(segment: .daily(during: interval), applications: applications)
    }

    static func weekFilter(
        referenceDate: Date = Date(),
        applications: Set<ApplicationToken> = [],
        calendar: Calendar = .current
    ) -> DeviceActivityFilter {
        let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate)
            ?? DateInterval(start: calendar.startOfDay(for: referenceDate), end: referenceDate)
        return makeFilter(segment: .weekly(during: interval), applications: applications)
    }

    static func unionInterval(from windows: [SessionReportTimeWindow]) -> DateInterval? {
        guard !windows.isEmpty,
              let start = windows.map(\.startAt).min(),
              let end = windows.map(\.stopAt).max(),
              end > start else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }

    static func todaySessionsFilter(
        windows: [SessionReportTimeWindow],
        applications: Set<ApplicationToken> = []
    ) -> DeviceActivityFilter? {
        guard let interval = unionInterval(from: windows) else { return nil }
        return makeFilter(segment: .hourly(during: interval), applications: applications)
    }

    static func weekSessionsFilter(
        windows: [SessionReportTimeWindow],
        applications: Set<ApplicationToken> = []
    ) -> DeviceActivityFilter? {
        guard let interval = unionInterval(from: windows) else { return nil }
        return makeFilter(segment: .weekly(during: interval), applications: applications)
    }

    private static func makeFilter(
        segment: DeviceActivityFilter.SegmentInterval,
        applications: Set<ApplicationToken>
    ) -> DeviceActivityFilter {
        if applications.isEmpty {
            return DeviceActivityFilter(
                segment: segment,
                users: .all,
                devices: DeviceActivityFilter.Devices([.iPhone, .iPad])
            )
        }
        return DeviceActivityFilter(
            segment: segment,
            users: .all,
            devices: DeviceActivityFilter.Devices([.iPhone, .iPad]),
            applications: applications
        )
    }
}
