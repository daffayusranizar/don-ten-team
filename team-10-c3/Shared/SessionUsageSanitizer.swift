import Foundation

/// Drops only the old three-app mock snapshot (YouTube + TikTok + Games), not real Screen Time rows with those apps.
enum SessionUsageSanitizer {
    private static let legacyMockBundleIDs: Set<String> = [
        "com.google.ios.youtube",
        "com.zhiliaoapp.musically",
        "com.apple.game",
    ]

    private static let legacyMockDisplayNames: Set<String> = [
        "YouTube",
        "TikTok",
        "Games",
    ]

    /// True when the payload is exactly the pre-integration placeholder trio (no partial matches).
    static func isLegacyMockPayload(_ payload: SessionUsagePayload) -> Bool {
        isLegacyMockAppList(payload.apps)
    }

    static func isLegacyMockAppList(_ apps: [AppUsageRow]) -> Bool {
        guard apps.count == 3 else { return false }
        let bundles = Set(apps.map(\.bundleIdentifier))
        let names = Set(apps.map(\.displayName))
        return bundles == legacyMockBundleIDs || names == legacyMockDisplayNames
    }

    static func sanitizedApps(_ apps: [AppUsageRow]) -> [AppUsageRow] {
        isLegacyMockAppList(apps) ? [] : apps
    }

    static func sanitizedPayload(_ payload: SessionUsagePayload) -> SessionUsagePayload {
        guard isLegacyMockPayload(payload) else { return payload }
        return SessionUsagePayload(
            childId: payload.childId,
            startAt: payload.startAt,
            stopAt: payload.stopAt,
            totalSeconds: 0,
            apps: []
        )
    }
}
