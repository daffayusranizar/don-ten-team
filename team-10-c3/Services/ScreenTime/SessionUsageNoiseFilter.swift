import Foundation

/// Drops Screen Time rows that are not user-facing apps (system services, tokens, Apple internals).
enum SessionUsageNoiseFilter {
    /// Apple apps parents might recognize in usage lists.
    private static let allowedAppleBundleIDs: Set<String> = [
        "com.apple.mobilesafari",
        "com.apple.mobilesms",
        "com.apple.mobilemail",
        "com.apple.mobilenotes",
        "com.apple.mobileslideshow",
        "com.apple.camera",
        "com.apple.music",
        "com.apple.tv",
        "com.apple.podcasts",
        "com.apple.maps",
        "com.apple.weather",
        "com.apple.calculator",
        "com.apple.facetime",
        "com.apple.health",
        "com.apple.reminders",
        "com.apple.mobilecal",
        "com.apple.passbook",
        "com.apple.store",
        "com.apple.documentsapp",
    ]

    private static let hiddenBundleFragments = [
        "localauthentication",
        "fcauthentication",
        "authentication",
        "image-detection",
        "springboard",
        "backboard",
        "frontboard",
        "backboardd",
        "mediaremote",
        "coreduet",
        "symptoms",
        "parsecd",
        "suggestd",
        "navd",
        "assetsd",
        "uiservice",
        "extensionservice",
        "xpc",
        "xpcservice",
        "coreauth",
        "authkit",
        "notificationcenter",
        "screenshot",
        "diagnostic",
        "corelocation",
        "intents",
        "intentservice",
        "intenthandler",
        "widget",
        "widgetextension",
        "shareextension",
        "service",
        "helper",
        "daemon",
        "appex",
        "pluginkit",
        "passd",
        "keychain",
        "trustd",
        "securityuibroker",
    ]

    private static let hiddenNameFragments = [
        "uiservice",
        "authentication",
        "image-detection",
        "detection",
        "extension",
        "daemon",
        "agent",
        "helper",
        "broker",
    ]

    #if DEBUG
    private(set) static var lastDroppedNoiseCount = 0

    static func resetDebugCounters() {
        lastDroppedNoiseCount = 0
    }
    #endif

    static func isUserFacingUsage(bundleId: String, displayName: String) -> Bool {
        !shouldHide(bundleId: bundleId, displayName: displayName)
    }

    /// Persisted / aggregated rows: filter only, no display-name normalization.
    static func userFacingApps(_ apps: [AppUsageRow]) -> [AppUsageRow] {
        apps.filter { isUserFacingUsage(bundleId: $0.bundleIdentifier, displayName: $0.displayName) }
    }

    /// Dashboard chart: filter + friendly app labels.
    static func appsForDisplay(_ apps: [AppUsageRow]) -> [AppUsageRow] {
        userFacingApps(apps).map { normalizeDisplayName($0) }
    }

    #if DEBUG
    static func logDropped(bundleId: String, displayName: String, seconds: Int) {
        lastDroppedNoiseCount += 1
        AgentDebugLog.log(
            hypothesisId: "C",
            location: "SessionUsageNoiseFilter.dropped",
            message: "filtered system/background noise row",
            data: [
                "bundleId": bundleId,
                "displayName": displayName,
                "seconds": String(seconds),
            ]
        )
    }
    #endif

    private static func shouldHide(bundleId: String, displayName: String) -> Bool {
        let bundle = bundleId.lowercased()
        let name = displayName.lowercased()

        if KnownAppLabels.isKnownConsumerBundle(bundleId)
            || allowedAppleBundleIDs.contains(bundle) {
            return false
        }

        if bundle.contains("applicationtoken") || bundle.contains("managedsettings") {
            return true
        }

        if !bundle.contains(".") {
            return true
        }

        if bundle.hasPrefix("com.apple."), !allowedAppleBundleIDs.contains(bundle) {
            return true
        }

        if hiddenBundleFragments.contains(where: { bundle.contains($0) }) {
            return true
        }
        if hiddenNameFragments.contains(where: { name.contains($0) }) {
            return true
        }

        if name.count <= 4, !looksLikeKnownConsumerApp(bundle: bundle, name: name) {
            return true
        }

        return false
    }

    private static func looksLikeKnownConsumerApp(bundle: String, name: String) -> Bool {
        let knownFragments = [
            "instagram", "tiktok", "youtube", "snapchat", "facebook",
            "whatsapp", "telegram", "discord", "reddit", "twitter",
            "netflix", "spotify", "amazon", "gmail", "google",
            "minecraft", "roblox", "fortnite",
        ]
        return knownFragments.contains { bundle.contains($0) || name.contains($0) }
    }

    private static func normalizeDisplayName(_ app: AppUsageRow) -> AppUsageRow {
        let displayName = KnownAppLabels.displayName(
            bundleId: app.bundleIdentifier,
            localized: app.displayName
        )
        return AppUsageRow(
            displayName: displayName,
            bundleIdentifier: app.bundleIdentifier,
            durationSeconds: app.durationSeconds
        )
    }
}
