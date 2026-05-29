//
//  SummaryCard.swift
//  team-10-c3
//

import SwiftUI

private enum WeeklyUsageInsightLayout {
    static let cornerRadius: CGFloat = 25
    static let contentPadding: CGFloat = 17
}

struct WeeklyUsageInsightCard: View {
    var title: String = "This week usage insight"
    let segments: [UsageCategorySegment]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.textPrimary)

            UsageRingView(segments: segments)
                .frame(maxWidth: .infinity)
                .padding(.top, 19)

            VStack(spacing: 8) {
                ForEach(segments) { segment in
                    CategoryUsageRow(segment: segment)
                }
            }
            .padding(.top, 16)
        }
        .padding(WeeklyUsageInsightLayout.contentPadding)
        .background(.uiBackground)
        .clipShape(RoundedRectangle(cornerRadius: WeeklyUsageInsightLayout.cornerRadius))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 2, y: 2)
    }
}

// MARK: - Preview

#Preview("Weekly Usage Insight Card") {
    WeeklyUsageInsightCard(segments: UsageCategorySegment.previewData)
        .padding()
        .background(.uiBackground)
}
