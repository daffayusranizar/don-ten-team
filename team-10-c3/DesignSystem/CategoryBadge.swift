//
//  CategoryBadge.swift
//  team-10-c3
//

import SwiftUI

struct CategoryUsageRow: View {
    let segment: UsageCategorySegment

    @ChartDifferentiateWithoutColor private var differentiateWithoutColor

    private var segmentStyle: (pattern: ChartFillPattern, image: String) {
        UsageCategoryVisualStyle.segmentStyle(for: segment)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: segment.systemImage)
                .font(.system(size: 20))
                .foregroundStyle(segment.color)
                .frame(width: 23, height: 24)

            if differentiateWithoutColor {
                ChartLegendSwatch(
                    color: segment.color,
                    pattern: segmentStyle.pattern,
                    systemImage: segmentStyle.image,
                    cacheKey: segment.title,
                    differentiateWithoutColor: true
                )
                .frame(width: 14, height: 14)
            }

            Text(segment.title)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .frame(height: 19)
                .background(titleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay {
                    if differentiateWithoutColor {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                    }
                }

            Spacer(minLength: 8)

            Text(DurationFormatting.hoursAndMinutes(segment.duration))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.textPrimary)
        }
        .frame(height: 24)
    }

    private var titleBackground: some ShapeStyle {
        UsageCategoryVisualStyle.fillStyle(
            color: segment.color,
            name: segment.title,
            differentiateWithoutColor: differentiateWithoutColor
        )
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

#Preview("Category Usage Row — Differentiate Without Color") {
    VStack(spacing: 8) {
        ForEach(UsageCategorySegment.previewData) { segment in
            CategoryUsageRow(segment: segment)
        }
    }
    .padding()
    .differentiateWithoutColorPreview()
}
