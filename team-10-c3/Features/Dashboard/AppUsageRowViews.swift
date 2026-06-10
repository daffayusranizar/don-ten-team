import SwiftUI

enum AppUsageIcon {
    /// Branded asset icons only — SF Symbols must use `AppUsageIconView` (they render blank with `.resizable().scaledToFill()`).
    static func assetImage(bundleIdentifier: String) -> Image? {
        let bundle = bundleIdentifier.lowercased()

        if KnownAppLabels.matches(bundleId: bundle, app: .instagram) {
            return ImageAsset.instagram.image
        }
        if KnownAppLabels.matches(bundleId: bundle, app: .tiktok) {
            return ImageAsset.tiktok.image
        }
        if KnownAppLabels.matches(bundleId: bundle, app: .youtube) {
            return ImageAsset.youtube.image
        }
        return nil
    }

    static func systemSymbol(bundleIdentifier: String) -> String {
        let bundle = bundleIdentifier.lowercased()

        if KnownAppLabels.matches(bundleId: bundle, app: .threads) {
            return "at"
        }
        if bundle.contains("safari") || bundle.contains("mobilesafari") {
            return "safari"
        }
        if bundle.contains("mobilesms") || bundle.contains("messages") {
            return "message.fill"
        }
        if bundle.contains("preferences") || bundle.contains("settings") {
            return "gearshape.fill"
        }
        if bundle.hasPrefix("com.apple.") {
            return "apple.logo"
        }
        return "app.fill"
    }
}

struct AppUsageIconView: View {
    let bundleIdentifier: String
    var size: CGFloat = 30
    var cornerRadius: CGFloat = 10

    var body: some View {
        if let asset = AppUsageIcon.assetImage(bundleIdentifier: bundleIdentifier) {
            asset
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            Image(systemName: AppUsageIcon.systemSymbol(bundleIdentifier: bundleIdentifier))
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

struct AppUsageListRow: View {
    let app: AppUsageRow

    var body: some View {
        HStack {
            AppUsageIconView(bundleIdentifier: app.bundleIdentifier)

            Text(app.displayName)
                .font(.system(size: 14, weight: .regular))
                .lineLimit(1)

            Spacer()

            Text(DurationFormatting.hoursAndMinutes(TimeInterval(app.durationSeconds)))
                .font(.system(size: 14, weight: .medium))
        }
    }
}
