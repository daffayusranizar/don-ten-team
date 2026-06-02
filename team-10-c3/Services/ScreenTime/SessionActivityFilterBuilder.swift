import DeviceActivity
import Foundation

/// Builds `DeviceActivityFilter` values for `activityData` queries.
@available(iOS 26.4, *)
enum SessionActivityFilterBuilder {
    struct LabeledFilter: Sendable {
        let filter: DeviceActivityFilter
        let label: String
    }

    /// Single session-scoped hourly filter (best match for short parent sessions).
    static func filters(startAt: Date, stopAt: Date) -> [LabeledFilter] {
        let sessionEnd = max(stopAt, startAt.addingTimeInterval(1))
        let sessionInterval = DateInterval(start: startAt, end: sessionEnd)

        let filter = LabeledFilter(
            filter: DeviceActivityFilter(
                segment: .hourly(during: sessionInterval),
                users: .all,
                devices: DeviceActivityFilter.Devices([.iPhone, .iPad])
            ),
            label: "hourly+session"
        )

        ScreenTimePipelineLogger.logFilter(
            label: filter.label,
            startAt: startAt,
            stopAt: stopAt,
            segment: "hourly(during: sessionInterval)",
            users: "all",
            devices: "iPhone,iPad",
            applicationTokenCount: 0
        )

        return [filter]
    }
}
