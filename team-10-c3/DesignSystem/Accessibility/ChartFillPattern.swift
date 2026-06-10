//
//  ChartFillPattern.swift
//  team-10-c3
//

import SwiftUI

/// Tiled fill patterns for chart segments when Differentiate Without Color is enabled.
enum ChartFillPattern: String, CaseIterable, Equatable {
    case solid
    case dots
    case diagonalStripes
    case horizontalStripes
    case crosshatch

    func shapeStyle(base: Color, cacheKey: String) -> AnyShapeStyle {
        switch self {
        case .solid:
            AnyShapeStyle(base)
        default:
            AnyShapeStyle(imagePaint(base: base, cacheKey: cacheKey))
        }
    }

    /// Combines a category pattern with an optional overlay (e.g. partial-hour dots).
    func shapeStyle(
        base: Color,
        cacheKey: String,
        overlay: ChartFillPattern?
    ) -> AnyShapeStyle {
        guard let overlay, overlay != .solid else {
            return shapeStyle(base: base, cacheKey: cacheKey)
        }
        return AnyShapeStyle(
            imagePaint(base: base, cacheKey: cacheKey, overlay: overlay)
        )
    }

    func imagePaint(base: Color, cacheKey: String) -> ImagePaint {
        ImagePaint(image: tileImage(base: base, cacheKey: cacheKey), scale: 1)
    }

    private func imagePaint(
        base: Color,
        cacheKey: String,
        overlay: ChartFillPattern
    ) -> ImagePaint {
        ImagePaint(
            image: tileImage(base: base, cacheKey: cacheKey, overlay: overlay),
            scale: 1
        )
    }

    // MARK: - Tile cache

    private static let tilePoints: CGFloat = 10
    private static var cache: [String: Image] = [:]

    @MainActor
    private static func tileImage(
        base: Color,
        cacheKey: String,
        pattern: ChartFillPattern,
        overlay: ChartFillPattern? = nil
    ) -> Image {
        let compositeKey = [cacheKey, pattern.rawValue, overlay?.rawValue]
            .compactMap { $0 }
            .joined(separator: "|")
        if let cached = cache[compositeKey] {
            return cached
        }

        let tile = ZStack {
            Rectangle().fill(base)
            Canvas { context, size in
                pattern.draw(into: &context, size: size)
                overlay?.draw(into: &context, size: size)
            }
        }
        .frame(width: tilePoints, height: tilePoints)

        let renderer = ImageRenderer(content: tile)
        renderer.scale = 3
        guard let cgImage = renderer.cgImage else {
            let fallback = Image(size: CGSize(width: 1, height: 1)) { context in
                let rect = CGRect(origin: .zero, size: CGSize(width: 1, height: 1))
                context.fill(Path(rect), with: .color(base))
            }
            cache[compositeKey] = fallback
            return fallback
        }
        let image = Image(decorative: cgImage, scale: 3)
        cache[compositeKey] = image
        return image
    }

    @MainActor
    private func tileImage(
        base: Color,
        cacheKey: String,
        overlay: ChartFillPattern? = nil
    ) -> Image {
        Self.tileImage(base: base, cacheKey: cacheKey, pattern: self, overlay: overlay)
    }

    // MARK: - Drawing

    private func draw(into context: inout GraphicsContext, size: CGSize) {
        switch self {
        case .solid:
            break
        case .dots:
            drawDots(into: &context, size: size)
        case .diagonalStripes:
            drawStripes(into: &context, size: size, angle: .pi / 4)
        case .horizontalStripes:
            drawStripes(into: &context, size: size, angle: 0)
        case .crosshatch:
            drawStripes(into: &context, size: size, angle: .pi / 4)
            drawStripes(into: &context, size: size, angle: -.pi / 4)
        }
    }

    private func drawDots(into context: inout GraphicsContext, size: CGSize) {
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

    private func drawStripes(into context: inout GraphicsContext, size: CGSize, angle: CGFloat) {
        let stripeColor = Color.black.opacity(0.2)
        let stripeWidth: CGFloat = 1.5
        let spacing: CGFloat = 4
        let diagonal = hypot(size.width, size.height)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        var offset = -diagonal
        while offset < diagonal {
            var path = Path()
            let dx = cos(angle + .pi / 2) * offset
            let dy = sin(angle + .pi / 2) * offset
            let along = CGPoint(x: cos(angle) * diagonal, y: sin(angle) * diagonal)
            path.move(to: CGPoint(x: center.x + dx - along.x, y: center.y + dy - along.y))
            path.addLine(to: CGPoint(x: center.x + dx + along.x, y: center.y + dy + along.y))
            context.stroke(path, with: .color(stripeColor), lineWidth: stripeWidth)
            offset += spacing + stripeWidth
        }
    }

    /// Stable pattern per dashboard hourly palette slot.
    static func forHourlyColorName(_ colorName: String) -> ChartFillPattern {
        switch colorName {
        case "sky": return .horizontalStripes
        case "yellow": return .dots
        case "mint": return .diagonalStripes
        case "coral": return .crosshatch
        case "purple": return .horizontalStripes
        case "orange": return .diagonalStripes
        default: return .dots
        }
    }
}
