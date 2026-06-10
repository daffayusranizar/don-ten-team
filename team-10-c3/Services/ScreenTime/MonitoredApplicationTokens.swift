import Foundation

enum MonitoredAppsFilter {
    private static var allowedBundleIds: Set<String> = []

    static func setAllowedBundleIds(_ bundleIds: Set<String>) {
        allowedBundleIds = bundleIds
    }

    static func noteResolvedBundleId(_ bundleId: String) {
        allowedBundleIds.insert(bundleId)
    }

    static func includes(bundleId: String) -> Bool {
        allowedBundleIds.contains(bundleId)
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
