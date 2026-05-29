//
//  CategoryBadge.swift
//  team-10-c3
//

import SwiftUI

struct CategoryUsageRow: View {
    let segment: UsageCategorySegment

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: segment.systemImage)
                .font(.system(size: 20))
                .foregroundStyle(segment.color)
                .frame(width: 23, height: 24)

            Text(segment.title)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .frame(height: 19)
                .background(segment.color)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Spacer(minLength: 8)

            Text(DurationFormatting.hoursAndMinutes(segment.duration))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.textPrimary)
        }
        .frame(height: 24)
    }
}

// MARK: - Preview

#Preview("Category Usage Row") {
    VStack(spacing: 8) {
        ForEach(UsageCategorySegment.previewData) { segment in
            CategoryUsageRow(segment: segment)
        }
    }
    .padding()
}
