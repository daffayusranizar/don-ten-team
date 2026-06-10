import SwiftUI

enum AppUsageIcon {
    /// Icons follow bundle ID only — display names from Screen Time are often wrong.
    static func image(for app: AppUsageRow) -> Image {
        image(bundleIdentifier: app.bundleIdentifier)
    }

    static func image(bundleIdentifier: String) -> Image {
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
        if bundle.contains("safari") || bundle.contains("mobilesafari") {
            return Image(systemName: "safari")
        }
        if bundle.contains("mobilesms") || bundle.contains("messages") {
            return Image(systemName: "message.fill")
        }
        if bundle.contains("preferences") || bundle.contains("settings") {
            return Image(systemName: "gearshape.fill")
        }
        if bundle.hasPrefix("com.apple.") {
            return Image(systemName: "apple.logo")
        }
        return Image(systemName: "app.fill")
    }
}

struct AppUsageListRow: View {
    let app: AppUsageRow

    var body: some View {
        HStack {
            AppUsageIcon.image(for: app)
                .resizable()
                .scaledToFill()
                .frame(width: 30, height: 30)
                .cornerRadius(10)

            Text(app.displayName)
                .font(.system(size: 14, weight: .regular))
                .lineLimit(1)

            Spacer()

            Text(DurationFormatting.hoursAndMinutes(TimeInterval(app.durationSeconds)))
                .font(.system(size: 14, weight: .medium))
        }
    }
}
