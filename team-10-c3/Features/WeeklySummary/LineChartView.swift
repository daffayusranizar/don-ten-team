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

struct LineChartView: View {
    let chartData: [ViewingData] = [

        .init(day: "Mon", percentage: 32, series: "Average Last 4 Week"),
        .init(day: "Tue", percentage: 40, series: "Average Last 4 Week"),
        .init(day: "Wed", percentage: 32, series: "Average Last 4 Week"),
        .init(day: "Thu", percentage: 42, series: "Average Last 4 Week"),
        .init(day: "Fri", percentage: 43, series: "Average Last 4 Week"),
        .init(day: "Sat", percentage: 38, series: "Average Last 4 Week"),
        .init(day: "Sun", percentage: 52, series: "Average Last 4 Week"),
        
        .init(day: "Mon", percentage: 44, series: "Current Week"),
        .init(day: "Tue", percentage: 66, series: "Current Week"),
        .init(day: "Wed", percentage: 41, series: "Current Week"),
        .init(day: "Thu", percentage: 36, series: "Current Week"),
        .init(day: "Fri", percentage: 52, series: "Current Week"),
        .init(day: "Sat", percentage: 55, series: "Current Week"),
        .init(day: "Sun", percentage: 58, series: "Current Week")
    ]
    
    let yAxisValues = Array(stride(from: 0, through: 90, by: 15))
    
    var body: some View {
        CardView(width: 346, height: 265) {
            VStack {
                Chart(chartData) { item in
                    LineMark(
                        x: .value("Day", item.day),
                        y: .value("Percentage", item.percentage)
                    )
                    .foregroundStyle(by: .value("Series", item.series))
                    .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
                .chartForegroundStyleScale([
                    "Average Last 4 Week": Color.blue.opacity(0.8),
                    "Current Week": Color.orange.opacity(0.8)
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
                .chartLegend(position: .bottom, alignment: .center, spacing: 16)
            }
            .padding(24)
            .frame(height: 265)
        }
    }
}

#Preview {
    ZStack {
        Color(uiColor: .secondarySystemBackground)
            .ignoresSafeArea()
        LineChartView()
    }
}
