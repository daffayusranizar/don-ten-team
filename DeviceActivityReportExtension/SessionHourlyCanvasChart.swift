import SwiftUI

/// Stacked hourly bars on a full 24-hour day axis with a labeled Y axis (minutes).
struct SessionHourlyCanvasChart: View {
    let segments: [SessionUsageReportConfiguration.HourlySegment]

    private static let hoursInDay = Array(0..<24)
    private static let yAxisWidth: CGFloat = 34

    private var segmentsByHour: [Int: [SessionUsageReportConfiguration.HourlySegment]] {
        Dictionary(grouping: segments, by: { $0.hour % 24 })
    }

    private var maxHourTotal: Int {
        let totals = Self.hoursInDay.map { hour in
            (segmentsByHour[hour] ?? []).map(\.durationSeconds).reduce(0, +)
        }
        return max(totals.max() ?? 0, 1)
    }

    private var yAxisTicks: [Int] {
        let maxMinutes = max(1, Int(ceil(Double(maxHourTotal) / 60.0)))
        let step = niceMinuteStep(for: maxMinutes)
        var ticks = [0]
        var value = step
        while value < maxMinutes {
            ticks.append(value)
            value += step
        }
        if ticks.last != maxMinutes {
            ticks.append(maxMinutes)
        }
        return ticks
    }

    private var yScaleMaxMinutes: Int {
        max(yAxisTicks.last ?? 1, 1)
    }

    private var legendApps: [(name: String, color: Color)] {
        var seen = Set<String>()
        var items: [(String, Color)] = []
        for segment in segments.sorted(by: { $0.durationSeconds > $1.durationSeconds }) {
            guard seen.insert(segment.appName).inserted else { continue }
            items.append((segment.appName, segment.color))
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage by hour")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            GeometryReader { geometry in
                let plotWidth = geometry.size.width - Self.yAxisWidth
                let slotWidth = plotWidth / CGFloat(Self.hoursInDay.count)
                let plotHeight = geometry.size.height - 18

                HStack(alignment: .top, spacing: 4) {
                    yAxisLabels(plotHeight: plotHeight)
                        .frame(width: Self.yAxisWidth, height: plotHeight)

                    VStack(spacing: 4) {
                        chartPlot(slotWidth: slotWidth, plotHeight: plotHeight)
                            .frame(width: plotWidth, height: plotHeight)
                        hourAxisLabels(slotWidth: slotWidth)
                            .frame(width: plotWidth)
                    }
                }
            }
            .frame(height: 158)

            if !legendApps.isEmpty {
                legendRow
            }
        }
    }

    private func chartPlot(slotWidth: CGFloat, plotHeight: CGFloat) -> some View {
        Canvas { context, size in
            let barWidth = min(8, slotWidth * 0.55)
            let yScaleSeconds = yScaleMaxMinutes * 60

            for minutes in yAxisTicks {
                let y = yPosition(forMinutes: minutes, plotHeight: plotHeight)
                var gridPath = Path()
                gridPath.move(to: CGPoint(x: 0, y: y))
                gridPath.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(
                    gridPath,
                    with: .color(.secondary.opacity(minutes == 0 ? 0.45 : 0.2)),
                    lineWidth: minutes == 0 ? 0.75 : 0.5
                )
            }

            for hour in Self.hoursInDay {
                let x = CGFloat(hour) * slotWidth
                let tickX = x + slotWidth / 2

                var tickPath = Path()
                tickPath.move(to: CGPoint(x: tickX, y: plotHeight))
                tickPath.addLine(to: CGPoint(x: tickX, y: plotHeight + 3))
                context.stroke(tickPath, with: .color(.secondary.opacity(0.3)), lineWidth: 0.5)

                let hourSegments = segmentsByHour[hour] ?? []
                let total = hourSegments.map(\.durationSeconds).reduce(0, +)
                guard total > 0 else { continue }

                let columnHeight = plotHeight * CGFloat(total) / CGFloat(yScaleSeconds)
                let barX = x + (slotWidth - barWidth) / 2
                var y = plotHeight

                let ordered = hourSegments.sorted { $0.durationSeconds > $1.durationSeconds }
                for segment in ordered {
                    let ratio = CGFloat(segment.durationSeconds) / CGFloat(total)
                    let segmentHeight = max(2, columnHeight * ratio)
                    y -= segmentHeight
                    let rect = CGRect(x: barX, y: y, width: barWidth, height: segmentHeight)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 2, style: .continuous),
                        with: .color(segment.color)
                    )
                }
            }
        }
    }

    private func yAxisLabels(plotHeight: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Text("min")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .offset(y: -2)

            ForEach(yAxisTicks, id: \.self) { minutes in
                Text(yAxisLabel(minutes))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .position(
                        x: Self.yAxisWidth / 2,
                        y: yPosition(forMinutes: minutes, plotHeight: plotHeight)
                    )
            }
        }
    }

    private func hourAxisLabels(slotWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Self.hoursInDay, id: \.self) { hour in
                Group {
                    if hour % 6 == 0 {
                        Text(hourLabel(hour))
                    } else {
                        Text(" ")
                    }
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: slotWidth)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }
        }
    }

    private var legendRow: some View {
        HStack(spacing: 12) {
            ForEach(Array(legendApps.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 4) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 6, height: 6)
                    Text(item.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func yPosition(forMinutes minutes: Int, plotHeight: CGFloat) -> CGFloat {
        let fraction = CGFloat(minutes) / CGFloat(yScaleMaxMinutes)
        return plotHeight * (1 - fraction)
    }

    private func yAxisLabel(_ minutes: Int) -> String {
        minutes == 0 ? "0" : "\(minutes)m"
    }

    private func niceMinuteStep(for maxMinutes: Int) -> Int {
        if maxMinutes <= 5 { return 1 }
        if maxMinutes <= 15 { return 5 }
        if maxMinutes <= 30 { return 10 }
        if maxMinutes <= 60 { return 15 }
        if maxMinutes <= 120 { return 30 }
        return 60
    }

    private func hourLabel(_ hour: Int) -> String {
        let normalized = hour % 24
        if normalized == 0 { return "12a" }
        if normalized < 12 { return "\(normalized)a" }
        if normalized == 12 { return "12p" }
        return "\(normalized - 12)p"
    }
}
