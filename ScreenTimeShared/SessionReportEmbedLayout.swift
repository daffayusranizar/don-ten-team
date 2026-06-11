import CoreGraphics
import Foundation

struct SessionReportRenderedMetrics: Sendable, Equatable {
    let appRowCount: Int
    let isEmpty: Bool
    let showsHourlyChart: Bool
    let hasRendered: Bool

    static let unknown = SessionReportRenderedMetrics(
        appRowCount: 0,
        isEmpty: true,
        showsHourlyChart: false,
        hasRendered: false
    )
}

enum SessionReportEmbedLayout {
    /// Apple documents that `DeviceActivityReport` needs a fixed host-app frame.
    static let minimumEmbedHeight: CGFloat = 260

    private static let periodBlock: CGFloat = 30
    private static let comparisonHeader: CGFloat = 22
    private static let comparisonRow: CGFloat = 48
    private static let comparisonPadding: CGFloat = 10
    private static let sessionRow: CGFloat = 30
    private static let footnote: CGFloat = 34
    private static let verticalPadding: CGFloat = 36
    private static let emptyBody: CGFloat = 96

    static func height(
        appRowCount: Int,
        isEmpty: Bool,
        showsSessionTime: Bool,
        showsHourlyChart: Bool
    ) -> CGFloat {
        if isEmpty {
            return periodBlock + emptyBody + footnote + verticalPadding
        }

        let rows = min(5, max(0, appRowCount))
        var total = periodBlock + footnote + verticalPadding
        if showsHourlyChart {
            total += comparisonChartHeight(rows: rows)
        }
        if showsSessionTime {
            total += sessionRow
        }
        return total
    }

    static func resolvedHeight(
        appRowCount: Int,
        isEmpty: Bool,
        showsSessionTime: Bool,
        showsHourlyChart: Bool
    ) -> CGFloat {
        let calculated = height(
            appRowCount: appRowCount,
            isEmpty: isEmpty,
            showsSessionTime: showsSessionTime,
            showsHourlyChart: showsHourlyChart
        )
        if isEmpty {
            return max(calculated, 180)
        }
        return max(calculated, minimumEmbedHeight)
    }

    static func estimatedHeight(
        allowedAppCount: Int,
        showsSessionTime: Bool,
        assumesEmpty: Bool = false,
        assumesHourlyChart: Bool = true
    ) -> CGFloat {
        if assumesEmpty {
            return height(
                appRowCount: 0,
                isEmpty: true,
                showsSessionTime: showsSessionTime,
                showsHourlyChart: false
            )
        }
        let rows = min(5, max(1, allowedAppCount))
        return resolvedHeight(
            appRowCount: rows,
            isEmpty: false,
            showsSessionTime: showsSessionTime,
            showsHourlyChart: assumesHourlyChart
        )
    }

    private static func comparisonChartHeight(rows: Int) -> CGFloat {
        comparisonHeader
            + CGFloat(rows) * comparisonRow
            + comparisonPadding
    }
}
