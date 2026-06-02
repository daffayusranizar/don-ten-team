import DeviceActivity
import Foundation
import ManagedSettings

/// Builds hourly `DeviceActivityFilter` values — one query per calendar hour the session touches.
@available(iOS 26.4, *)
enum SessionActivityFilterBuilder {
    struct LabeledFilter: Sendable {
        let filter: DeviceActivityFilter
        let label: String
        let hourStart: Date
    }

    static func filters(
        startAt: Date,
        stopAt: Date,
        applications: Set<ApplicationToken> = [],
        calendar: Calendar = .current
    ) -> [LabeledFilter] {
        let hourStarts = SessionUsageHourMerge.hourStartsOverlapping(
            startAt: startAt,
            stopAt: stopAt,
            calendar: calendar
        )

        let filters = hourStarts.compactMap { hourStart -> LabeledFilter? in
            guard let hourInterval = calendar.dateInterval(of: .hour, for: hourStart) else {
                return nil
            }
            let label = "hourly+\(ISO8601DateFormatter().string(from: hourStart))"
            let filter = LabeledFilter(
                filter: makeFilter(hourInterval: hourInterval, applications: applications),
                label: label,
                hourStart: hourStart
            )
            logFilter(label: label, hourInterval: hourInterval, applications: applications)
            return filter
        }

        if filters.isEmpty {
            let sessionEnd = max(stopAt, startAt.addingTimeInterval(1))
            let sessionInterval = DateInterval(start: startAt, end: sessionEnd)
            let hourStart = calendar.dateInterval(of: .hour, for: startAt)?.start ?? startAt
            return [
                LabeledFilter(
                    filter: makeFilter(hourInterval: sessionInterval, applications: applications),
                    label: "hourly+session-fallback",
                    hourStart: hourStart
                ),
            ]
        }

        return filters
    }

    /// Single calendar-hour filter for chart-time fetches.
    static func filterForHour(
        hourStart: Date,
        applications: Set<ApplicationToken> = [],
        calendar: Calendar = .current
    ) -> LabeledFilter? {
        guard let hourInterval = calendar.dateInterval(of: .hour, for: hourStart) else {
            return nil
        }
        let label = "hourly+\(ISO8601DateFormatter().string(from: hourStart))"
        let filter = LabeledFilter(
            filter: makeFilter(hourInterval: hourInterval, applications: applications),
            label: label,
            hourStart: hourStart
        )
        logFilter(label: label, hourInterval: hourInterval, applications: applications)
        return filter
    }

    private static func makeFilter(
        hourInterval: DateInterval,
        applications: Set<ApplicationToken>
    ) -> DeviceActivityFilter {
        if applications.isEmpty {
            return DeviceActivityFilter(
                segment: .hourly(during: hourInterval),
                users: .all,
                devices: DeviceActivityFilter.Devices([.iPhone, .iPad])
            )
        }
        return DeviceActivityFilter(
            segment: .hourly(during: hourInterval),
            users: .all,
            devices: DeviceActivityFilter.Devices([.iPhone, .iPad]),
            applications: applications
        )
    }

    private static func logFilter(
        label: String,
        hourInterval: DateInterval,
        applications: Set<ApplicationToken>
    ) {
        ScreenTimePipelineLogger.logFilter(
            label: label,
            startAt: hourInterval.start,
            stopAt: hourInterval.end,
            segment: "hourly(during: hourInterval)",
            users: "all",
            devices: "iPhone,iPad",
            applicationTokenCount: applications.count
        )
    }
}
