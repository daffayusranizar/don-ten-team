import Foundation

struct HourlyChartUsageResult: Sendable, Equatable {
    let hourlyApps: [HourlyAppUsageRow]
    let apps: [AppUsageRow]
}
