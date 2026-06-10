//
//  LineChartView.swift
//  team-10-c3
//
//  Created by Daffa Yuranizar Arrifi on 05/06/26.
//

import SwiftUI
import Charts

// 1. Define the Data Model
struct ViewingData: Identifiable {
    let id = UUID()
    let day: String
    let percentage: Double
    let series: String
}

private enum LineChartSeries {
    static let average = "Average Last 4 Week"
    static let current = "Current Week"

    static var all: [String] { [average, current] }

    static func color(for series: String) -> Color {
        series == average ? Color.blue.opacity(0.8) : Color.orange.opacity(0.8)
    }

    static func isDashed(_ series: String) -> Bool {
        series == average
    }

    static func symbolName(for series: String) -> String {
        series == average ? "circle" : "diamond.fill"
    }
}

struct LineChartView: View {
    let chartData: [ViewingData] = [

        .init(day: "Mon", percentage: 32, series: LineChartSeries.average),
        .init(day: "Tue", percentage: 40, series: LineChartSeries.average),
        .init(day: "Wed", percentage: 32, series: LineChartSeries.average),
        .init(day: "Thu", percentage: 42, series: LineChartSeries.average),
        .init(day: "Fri", percentage: 43, series: LineChartSeries.average),
        .init(day: "Sat", percentage: 38, series: LineChartSeries.average),
        .init(day: "Sun", percentage: 52, series: LineChartSeries.average),

        .init(day: "Mon", percentage: 44, series: LineChartSeries.current),
        .init(day: "Tue", percentage: 66, series: LineChartSeries.current),
        .init(day: "Wed", percentage: 41, series: LineChartSeries.current),
        .init(day: "Thu", percentage: 36, series: LineChartSeries.current),
        .init(day: "Fri", percentage: 52, series: LineChartSeries.current),
        .init(day: "Sat", percentage: 55, series: LineChartSeries.current),
        .init(day: "Sun", percentage: 58, series: LineChartSeries.current)
    ]

    let yAxisValues = Array(stride(from: 0, through: 90, by: 15))

    @ChartDifferentiateWithoutColor private var differentiateWithoutColor

    var body: some View {
        CardView(minHeight: 265) {
            VStack(spacing: 12) {
                Chart(chartData) { item in
                    LineMark(
                        x: .value("Day", item.day),
                        y: .value("Percentage", item.percentage)
                    )
                    .foregroundStyle(by: .value("Series", item.series))
                    .lineStyle(lineStyle(for: item.series))
                    .symbol(by: .value("Series", item.series))
                    .symbolSize(differentiateWithoutColor ? 36 : 0)
                }
                .chartForegroundStyleScale([
                    LineChartSeries.average: LineChartSeries.color(for: LineChartSeries.average),
                    LineChartSeries.current: LineChartSeries.color(for: LineChartSeries.current)
                ])
                .chartSymbolScale([
                    LineChartSeries.average: Circle().strokeBorder(lineWidth: 2),
                    LineChartSeries.current: Circle()
                ])
                .chartYScale(domain: 0...90)
                .chartYAxis {
                    AxisMarks(position: .leading, values: yAxisValues) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxisLabel(position: .leading, alignment: .center) {
                    Text("Percentage of Viewing Time (%)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartLegend(differentiateWithoutColor ? .hidden : .visible)

                if differentiateWithoutColor {
                    lineChartPatternLegend
                }
            }
            .padding(24)
            .frame(minHeight: 265)
        }
    }

    private var lineChartPatternLegend: some View {
        HStack(spacing: 20) {
            ForEach(LineChartSeries.all, id: \.self) { series in
                HStack(spacing: 6) {
                    ChartLineStyleLegendSwatch(
                        color: LineChartSeries.color(for: series),
                        dashed: LineChartSeries.isDashed(series)
                    )
                    Image(systemName: LineChartSeries.symbolName(for: series))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(LineChartSeries.color(for: series))
                    Text(series)
                        .font(.caption2)
                        .foregroundStyle(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func lineStyle(for series: String) -> StrokeStyle {
        let base = StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        guard differentiateWithoutColor else { return base }
        if LineChartSeries.isDashed(series) {
            return StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [8, 4])
        }
        return base
    }
}

#Preview {
    ZStack {
        Color(uiColor: .secondarySystemBackground)
            .ignoresSafeArea()
        LineChartView()
    }
}

#Preview("Differentiate Without Color") {
    ZStack {
        Color(uiColor: .secondarySystemBackground)
            .ignoresSafeArea()
        LineChartView()
            .differentiateWithoutColorPreview()
    }
}
