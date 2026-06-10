import Foundation
import SwiftUI

struct HourlyStackedChartSegment: Identifiable, Equatable {
    var id: String { "\(hour)-\(bundleIdentifier)" }
    let hour: Int
    let hourLabel: String
    let appDisplayName: String
    let bundleIdentifier: String
    let durationSeconds: Int
    let colorName: String
    let isPartialHour: Bool

    var color: Color {
        switch colorName {
        case "sky": return .decorativeSkyBlue
        case "yellow": return .decorativeSunnyYellow
        case "mint": return .decorativeMintGreen
        case "coral": return .decorativeCoralPink
        case "purple": return .primarySoftPurple
        case "orange": return .decorativeCoralPink.opacity(0.85)
        default: return .decorativeSkyBlue
        }
    }

    var chartPattern: ChartFillPattern {
        ChartFillPattern.forHourlyColorName(colorName)
    }
}

enum HourlyStackedChartBuilder {
    private static let palette = ["sky", "yellow", "mint", "coral", "purple", "orange"]
    private static let maxApps = 8

    static func build(
        fromHourlyRows rows: [HourlyAppUsageRow],
        sessions: [SessionWindow]
    ) -> [HourlyStackedChartSegment] {
        let partialHours = SessionUsageHourMerge.partialHourNumbers(
            sessions: sessions.map { ($0.startAt, $0.stopAt) }
        )
        var byHourBundle: [Int: [String: (name: String, seconds: Int)]] = [:]

        for row in rows where row.durationSeconds > 0 {
            var hourMap = byHourBundle[row.hour] ?? [:]
            let existing = hourMap[row.bundleIdentifier]?.seconds ?? 0
            hourMap[row.bundleIdentifier] = (row.displayName, existing + row.durationSeconds)
            byHourBundle[row.hour] = hourMap
        }

        let bundleTotals = totalsPerBundle(from: byHourBundle)
        let rankedBundles = bundleTotals.sorted { $0.value > $1.value }.map(\.key)
        let chartBundles = Array(rankedBundles.prefix(maxApps))
        guard !chartBundles.isEmpty else { return [] }

        let colorByBundle = Dictionary(
            uniqueKeysWithValues: chartBundles.enumerated().map { index, bundle in
                (bundle, palette[index % palette.count])
            }
        )

        var segments: [HourlyStackedChartSegment] = []
        for hour in 0..<24 {
            let label = hourLabel(for: hour)
            for bundle in chartBundles {
                let seconds = byHourBundle[hour]?[bundle]?.seconds ?? 0
                guard seconds > 0 else { continue }
                let name = byHourBundle[hour]?[bundle]?.name ?? bundle
                segments.append(
                    HourlyStackedChartSegment(
                        hour: hour,
                        hourLabel: label,
                        appDisplayName: chartDisplayName(name),
                        bundleIdentifier: bundle,
                        durationSeconds: seconds,
                        colorName: colorByBundle[bundle] ?? "sky",
                        isPartialHour: partialHours.contains(hour)
                    )
                )
            }
        }
        return segments
    }

    static func hasChartData(_ segments: [HourlyStackedChartSegment]) -> Bool {
        segments.contains { $0.durationSeconds > 0 }
    }

    private static func totalsPerBundle(
        from byHourBundle: [Int: [String: (name: String, seconds: Int)]]
    ) -> [String: Int] {
        var totals: [String: Int] = [:]
        for hourMap in byHourBundle.values {
            for (bundle, entry) in hourMap {
                totals[bundle, default: 0] += entry.seconds
            }
        }
        return totals
    }

    private static func hourLabel(for hour: Int) -> String {
        switch hour {
        case 0: return "12a"
        case 1..<12: return "\(hour)a"
        case 12: return "12p"
        default: return "\(hour - 12)p"
        }
    }

    private static func chartDisplayName(_ name: String) -> String {
        if name.count <= 12 { return name }
        return String(name.prefix(11)) + "…"
    }
}
