//
//  UsageRingView.swift
//  team-10-c3
//

import Charts
import SwiftUI

struct UsageRingView: View {
    let segments: [UsageCategorySegment]

    private var totalDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        Group {
            if segments.isEmpty || totalDuration <= 0 {
                emptyRing
            } else {
                chart
            }
        }
        .frame(width: 120, height: 120)
    }

    private var chart: some View {
        Chart(segments) { segment in
            SectorMark(
                angle: .value("Duration", segment.duration),
                innerRadius: .ratio(0.55),
                angularInset: 1.5
            )
            .foregroundStyle(segment.color)
        }
        .chartLegend(.hidden)
    }

    private var emptyRing: some View {
        Circle()
            .stroke(Color.gray.opacity(0.25), lineWidth: 24)
    }
}

// MARK: - Preview

#Preview("Usage Ring") {
    UsageRingView(segments: UsageCategorySegment.previewData)
        .padding()
}
