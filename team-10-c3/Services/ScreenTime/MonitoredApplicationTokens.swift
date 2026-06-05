import Foundation

enum MonitoredAppsFilter {
    static func includes(bundleId: String) -> Bool {
        KnownAppLabels.matches(bundleId: bundleId, app: .tiktok)
            || KnownAppLabels.matches(bundleId: bundleId, app: .youtube)
    }

    static func userFacingApps(_ apps: [AppUsageRow]) -> [AppUsageRow] {
        apps.filter { includes(bundleId: $0.bundleIdentifier) }
    }

    static func appsForDisplay(_ apps: [AppUsageRow]) -> [AppUsageRow] {
        userFacingApps(apps).compactMap { app in
            let displayName = KnownAppLabels.displayName(
                bundleId: app.bundleIdentifier,
                localized: app.displayName
            )
            guard !KnownAppLabels.looksLikeBundleIdentifier(displayName) else { return nil }
            return AppUsageRow(
                displayName: displayName,
                bundleIdentifier: app.bundleIdentifier,
                durationSeconds: app.durationSeconds
            )
        }
    }
}
