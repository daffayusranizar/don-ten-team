import SwiftUI

/// Tiled dot fill for partial-hour chart bars (base app color + subtle dots).
enum HourlyChartDotPattern {
    static func fill(base: Color, cacheKey: String) -> ImagePaint {
        ChartFillPattern.dots.imagePaint(base: base, cacheKey: "partial-\(cacheKey)")
    }
}
