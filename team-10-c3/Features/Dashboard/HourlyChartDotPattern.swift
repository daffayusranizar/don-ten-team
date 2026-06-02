import SwiftUI

/// Tiled dot fill for partial-hour chart bars (base app color + subtle dots).
enum HourlyChartDotPattern {
    private static let tilePoints: CGFloat = 10
    private static var cache: [String: Image] = [:]

    static func fill(base: Color, cacheKey: String) -> ImagePaint {
        ImagePaint(image: tileImage(base: base, cacheKey: cacheKey), scale: 1)
    }

    @MainActor
    private static func tileImage(base: Color, cacheKey: String) -> Image {
        if let cached = cache[cacheKey] {
            return cached
        }

        let tile = ZStack {
            Rectangle().fill(base)
            Canvas { context, size in
                let dotRadius: CGFloat = 1.25
                let spacing: CGFloat = 5
                let dotColor = Color.black.opacity(0.22)
                var y = spacing * 0.5
                while y < size.height {
                    var x = spacing * 0.5
                    while x < size.width {
                        let rect = CGRect(
                            x: x - dotRadius,
                            y: y - dotRadius,
                            width: dotRadius * 2,
                            height: dotRadius * 2
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                        x += spacing
                    }
                    y += spacing
                }
            }
        }
        .frame(width: tilePoints, height: tilePoints)

        let renderer = ImageRenderer(content: tile)
        renderer.scale = 3
        guard let cgImage = renderer.cgImage else {
            let fallback = Image(size: CGSize(width: 1, height: 1)) { _ in base }
            cache[cacheKey] = fallback
            return fallback
        }
        let image = Image(decorative: cgImage, scale: 3)
        cache[cacheKey] = image
        return image
    }
}
