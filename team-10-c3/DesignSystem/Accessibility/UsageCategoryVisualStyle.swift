//
//  UsageCategoryVisualStyle.swift
//  team-10-c3
//

import SwiftUI

extension UsageInsightChartCategory {
    var systemImage: String {
        switch self {
        case .educational: "book.fill"
        case .entertainment: "tv.fill"
        case .commercial: "cart.fill"
        }
    }

    var chartPattern: ChartFillPattern {
        switch self {
        case .educational: .diagonalStripes
        case .entertainment: .dots
        case .commercial: .crosshatch
        }
    }

    static func fromChartItemName(_ name: String) -> UsageInsightChartCategory {
        if let category = UsageInsightChartCategory(rawValue: name) {
            return category
        }
        return fromPipelineLabel(name)
    }
}

enum UsageCategoryVisualStyle {
    static func category(for name: String) -> UsageInsightChartCategory {
        UsageInsightChartCategory.fromChartItemName(name)
    }

    static func color(for name: String) -> Color {
        category(for: name).color
    }

    static func systemImage(for name: String) -> String {
        category(for: name).systemImage
    }

    static func chartPattern(for name: String) -> ChartFillPattern {
        category(for: name).chartPattern
    }

    static func segmentStyle(for segment: UsageCategorySegment) -> (pattern: ChartFillPattern, image: String) {
        if let category = UsageInsightChartCategory(rawValue: segment.title) {
            return (category.chartPattern, category.systemImage)
        }
        return (.dots, segment.systemImage)
    }

    static func fillStyle(
        color: Color,
        name: String,
        differentiateWithoutColor: Bool
    ) -> AnyShapeStyle {
        guard differentiateWithoutColor else {
            return AnyShapeStyle(color)
        }
        let pattern = chartPattern(for: name)
        return pattern.shapeStyle(base: color, cacheKey: name)
    }

    static func fillStyle(
        color: Color,
        pattern: ChartFillPattern,
        cacheKey: String,
        differentiateWithoutColor: Bool
    ) -> AnyShapeStyle {
        guard differentiateWithoutColor else {
            return AnyShapeStyle(color)
        }
        return pattern.shapeStyle(base: color, cacheKey: cacheKey)
    }
}

// MARK: - Legend swatch

struct ChartLegendSwatch: View {
    let color: Color
    let pattern: ChartFillPattern
    var systemImage: String?
    var cacheKey: String
    var differentiateWithoutColor: Bool

    private let size: CGFloat = 10

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(swatchFill)
                .frame(width: size, height: size)

            if differentiateWithoutColor, let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.85, weight: .semibold))
                    .foregroundStyle(color)
            }
        }
        .accessibilityHidden(true)
    }

    private var swatchFill: AnyShapeStyle {
        guard differentiateWithoutColor else {
            return AnyShapeStyle(color)
        }
        return pattern.shapeStyle(base: color, cacheKey: cacheKey)
    }
}

struct ChartLineStyleLegendSwatch: View {
    let color: Color
    let dashed: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(.clear)
            .frame(width: 22, height: 8)
            .overlay {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 4))
                    path.addLine(to: CGPoint(x: 22, y: 4))
                }
                .stroke(
                    color,
                    style: dashed
                        ? StrokeStyle(lineWidth: 3, lineCap: .round, dash: [5, 3])
                        : StrokeStyle(lineWidth: 3, lineCap: .round)
                )
            }
            .accessibilityHidden(true)
    }
}

struct ChartPatternLegendRow: View {
    let title: String
    let color: Color
    let pattern: ChartFillPattern
    var systemImage: String?
    var cacheKey: String
    var differentiateWithoutColor: Bool
    var appIcon: Image?

    var body: some View {
        HStack(spacing: 6) {
            if let appIcon {
                appIcon
                    .resizable()
                    .scaledToFill()
                    .frame(width: 14, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            ChartLegendSwatch(
                color: color,
                pattern: pattern,
                systemImage: systemImage,
                cacheKey: cacheKey,
                differentiateWithoutColor: differentiateWithoutColor
            )

            Text(title)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }
}

// MARK: - Preview helper

private struct ChartDifferentiateOverrideKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

extension EnvironmentValues {
    /// Preview/test override for Differentiate Without Color (system key is read-only).
    var chartDifferentiateOverride: Bool? {
        get { self[ChartDifferentiateOverrideKey.self] }
        set { self[ChartDifferentiateOverrideKey.self] = newValue }
    }
}

@propertyWrapper
struct ChartDifferentiateWithoutColor: DynamicProperty {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var systemValue
    @Environment(\.chartDifferentiateOverride) private var override

    var wrappedValue: Bool {
        override ?? systemValue
    }
}

extension View {
    /// Applies the Differentiate Without Color accessibility setting for previews.
    func differentiateWithoutColorPreview(_ enabled: Bool = true) -> some View {
        environment(\.chartDifferentiateOverride, enabled)
    }
}
