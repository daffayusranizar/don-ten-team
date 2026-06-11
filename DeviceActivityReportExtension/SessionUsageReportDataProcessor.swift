import DeviceActivity
import Foundation
import ManagedSettings
import SwiftUI

enum SessionUsageReportDataProcessor {
    private struct AppAccumulator: Sendable {
        let token: ApplicationToken
        var displayName: String
        var durationSeconds: Int
    }

    static func makeConfiguration(
        title: String,
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> SessionUsageReportConfiguration {
        var appsByToken: [ApplicationToken: AppAccumulator] = [:]
        var hourlyByKey: [String: Int] = [:]

        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                let hour = Calendar.current.component(.hour, from: segment.dateInterval.start)
                for await category in segment.categories {
                    for await app in category.applications {
                        guard let token = app.application.token else { continue }
                        let name = app.application.localizedDisplayName ?? "App"
                        let seconds = max(0, Int(app.totalActivityDuration.rounded()))
                        guard seconds > 0 else { continue }

                        if var existing = appsByToken[token] {
                            existing.durationSeconds += seconds
                            if existing.displayName == "App", name != "App" {
                                existing.displayName = name
                            }
                            appsByToken[token] = existing
                        } else {
                            appsByToken[token] = AppAccumulator(
                                token: token,
                                displayName: name,
                                durationSeconds: seconds
                            )
                        }

                        let key = "\(hour)|\(name)"
                        hourlyByKey[key, default: 0] += seconds
                    }
                }
            }
        }

        let sortedApps = appsByToken.values
            .sorted { $0.durationSeconds > $1.durationSeconds }

        let appRows = sortedApps.enumerated().map { index, entry in
            SessionUsageReportConfiguration.AppRow(
                id: "app-\(index)",
                displayName: entry.displayName,
                durationSeconds: entry.durationSeconds,
                color: SessionUsageReportPalette.color(for: index),
                applicationToken: entry.token
            )
        }

        let sortedAppNames = sortedApps.map(\.displayName)
        let hourlySegments = hourlyByKey
            .map { key, seconds -> (hour: Int, name: String, seconds: Int) in
                let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
                let hour = Int(parts[0]) ?? 0
                let name = parts.count > 1 ? parts[1] : "App"
                return (hour, name, seconds)
            }
            .sorted { lhs, rhs in
                if lhs.hour != rhs.hour { return lhs.hour < rhs.hour }
                return lhs.name < rhs.name
            }
            .enumerated()
            .map { index, entry in
                let colorIndex = sortedAppNames.firstIndex(of: entry.name) ?? index
                return SessionUsageReportConfiguration.HourlySegment(
                    id: "\(entry.hour)-\(entry.name)",
                    hour: entry.hour,
                    appName: entry.name,
                    durationSeconds: entry.seconds,
                    color: SessionUsageReportPalette.color(for: colorIndex)
                )
            }

        let totalSeconds = appRows.map(\.durationSeconds).reduce(0, +)
        let display = SessionReportDisplayContext.read()
        let isEmpty = appRows.isEmpty
        SessionReportDisplayContext.writeRenderedMetrics(
            appRowCount: min(5, appRows.count),
            isEmpty: isEmpty,
            showsHourlyChart: !appRows.isEmpty
        )

        return SessionUsageReportConfiguration(
            title: title,
            periodTitle: display.periodTitle,
            childName: display.childName,
            sessionElapsedSeconds: display.sessionElapsedSeconds,
            apps: appRows,
            hourlySegments: hourlySegments,
            totalSeconds: totalSeconds,
            isEmpty: isEmpty
        )
    }
}
