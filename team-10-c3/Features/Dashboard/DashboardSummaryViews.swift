//
//  DashboardSummaryViews.swift
//  team-10-c3
//
//  Created by Huy Tran on 08/06/26.
//

import SwiftUI
import Charts
import UIKit

// MARK: Latest Summary
@ViewBuilder
func latestSummary(
    periodTitle: String,
    hourlySegments: [HourlyStackedChartSegment],
    topApps: [AppUsageRow],
    isUpdating: Bool = false,
    sessionElapsedSeconds: Int = 0,
    screenTimeAppTotalSeconds: Int = 0,
    showsTotalsMismatch: Bool = false
) -> some View {
    VStack(alignment: .leading) {
        HStack {
            Text("Latest Summary")
                .font(.system(size: 22, weight: .semibold))
            Spacer()
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(
                    "Kiddly counts session minutes with a timer. The chart stacks estimated per-app usage by hour for today."
                )
        }

        VStack(alignment: .center, spacing: 15) {
            Text(periodTitle)
                .font(.system(size: 18, weight: .semibold))

            if HourlyStackedChartBuilder.hasChartData(hourlySegments) {
                hourlyStackedAppChart(segments: hourlySegments)
                if hourlySegments.contains(where: \.isPartialHour) {
                    Text(
                        "Dotted bars: the parent session covered only part of that hour. App usage is an estimate for the whole hour bucket."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
            } else if isUpdating {
                summaryEmptyState(message: "Loading app usage…")
            } else {
                summaryEmptyState(
                    message: "No app usage for this period yet. End a session or pull to refresh."
                )
            }

            mostUsedApps(topApps: topApps)

            if sessionElapsedSeconds > 0 {
                Text("Session time (today): \(DurationFormatting.compact(seconds: sessionElapsedSeconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Measured while sessions were active.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if screenTimeAppTotalSeconds > 0 {
                Text("App usage (estimate): \(DurationFormatting.compact(seconds: screenTimeAppTotalSeconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Estimated from today's sessions. Times are approximate.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if showsTotalsMismatch {
                Text("Session time is measured precisely; per-app estimates can differ when several apps were used in one session.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 30)
        .background(.decorativeSkyBlue.opacity(0.13))
        .clipShape(
            RoundedRectangle(cornerRadius: 15)
        )
    }
    .padding(.top, 30)
}

// MARK: 24-hour stacked app usage
@ViewBuilder
func hourlyStackedAppChart(segments: [HourlyStackedChartSegment]) -> some View {
    HourlyStackedAppChart(segments: segments)
}

private struct HourlyStackedAppChart: View {
    let segments: [HourlyStackedChartSegment]

    @ChartDifferentiateWithoutColor private var differentiateWithoutColor

    var body: some View {
        let legendApps = Array(
            Dictionary(
                segments.map { ($0.bundleIdentifier, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            .values
        )
        .sorted { $0.appDisplayName.localizedCaseInsensitiveCompare($1.appDisplayName) == .orderedAscending }
        let appNames = legendApps.map(\.appDisplayName)
        let legendColors = legendApps.map(\.color)

        VStack(alignment: .leading, spacing: 8) {
            Chart(segments) { segment in
                BarMark(
                    x: .value("Hour", segment.hour),
                    y: .value("Seconds", segment.durationSeconds)
                )
                .foregroundStyle(hourlyBarForegroundStyle(segment))
            }
            .chartForegroundStyleScale(domain: appNames, range: legendColors)
            .chartXScale(domain: 0...23)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18]) { value in
                    if let hour = value.as(Int.self) {
                        AxisValueLabel(hourAxisLabel(hour))
                    }
                    AxisTick()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(DurationFormatting.compact(seconds: Int(number.rounded())))
                        }
                    }
                    AxisTick()
                }
            }
            .chartLegend(differentiateWithoutColor ? .hidden : .visible)
            .chartPlotStyle { plotArea in
                plotArea.border(.clear)
            }

            if differentiateWithoutColor {
                hourlyPatternLegend(apps: legendApps)
            }
        }
        .padding()
        .background(.uiBackground)
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }

    @ViewBuilder
    private func hourlyPatternLegend(apps: [HourlyStackedChartSegment]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(apps, id: \.bundleIdentifier) { app in
                ChartPatternLegendRow(
                    title: app.appDisplayName,
                    color: app.color,
                    pattern: app.chartPattern,
                    cacheKey: app.colorName,
                    differentiateWithoutColor: true,
                    bundleIdentifier: app.bundleIdentifier
                )
            }
        }
    }

    private func hourlyBarForegroundStyle(_ segment: HourlyStackedChartSegment) -> AnyShapeStyle {
        if differentiateWithoutColor {
            let pattern = segment.chartPattern
            if segment.isPartialHour {
                return pattern.shapeStyle(
                    base: segment.color,
                    cacheKey: segment.colorName,
                    overlay: .dots
                )
            }
            return pattern.shapeStyle(base: segment.color, cacheKey: segment.colorName)
        }

        if segment.isPartialHour {
            return AnyShapeStyle(
                HourlyChartDotPattern.fill(base: segment.color, cacheKey: segment.colorName)
            )
        }
        return AnyShapeStyle(segment.color)
    }
}

private func hourAxisLabel(_ hour: Int) -> String {
    switch hour {
    case 0: return "12a"
    case 1..<12: return "\(hour)a"
    case 12: return "12p"
    default: return "\(hour - 12)p"
    }
}

// MARK: Most Used Apps
@ViewBuilder
func mostUsedApps(topApps: [AppUsageRow]) -> some View {
    VStack {
        HStack {
            Text("App usage (estimate)")
                .font(.system(size: 16, weight: .semibold))
            Spacer()
        }

        VStack {
            if topApps.isEmpty {
                summaryEmptyState(message: "No app usage recorded for this period.")
            } else {
                ForEach(topApps) { app in
                    AppUsageListRow(app: app)
                }
            }
        }
    }
    .padding()
    .background(.uiBackground)
    .clipShape(
        RoundedRectangle(cornerRadius: 15)
    )
}

@ViewBuilder
private func summaryEmptyState(message: String) -> some View {
    Text(message)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
        .background(.uiBackground)
        .clipShape(RoundedRectangle(cornerRadius: 15))
}
