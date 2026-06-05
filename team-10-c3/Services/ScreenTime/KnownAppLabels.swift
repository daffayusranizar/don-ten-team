import Foundation

/// Maps bundle ID fragments to stable consumer-facing names (bundle is authoritative; Screen Time names are not).
enum KnownAppLabels {
    private static let rules: [(fragment: String, name: String)] = [
        ("instagram", "Instagram"),
        ("burbn.instagram", "Instagram"),
        ("tiktok", "TikTok"),
        ("musically", "TikTok"),
        ("zhiliaoapp", "TikTok"),
        ("trill", "TikTok"),
        ("aweme", "TikTok"),
        ("tiktokv", "TikTok"),
        ("ss.iphone.ugc", "TikTok"),
        ("ss.iphone", "TikTok"),
        ("youtube", "YouTube"),
        ("snapchat", "Snapchat"),
        ("facebook", "Facebook"),
        ("whatsapp", "WhatsApp"),
        ("telegram", "Telegram"),
        ("discord", "Discord"),
        ("reddit", "Reddit"),
        ("twitter", "X"),
        ("netflix", "Netflix"),
        ("spotify", "Spotify"),
        ("gmail", "Gmail"),
        ("google.chrome", "Chrome"),
        ("mobilesafari", "Safari"),
        ("mobilesms", "Messages"),
    ]

    static func displayName(bundleId: String, localized: String?) -> String {
        let bundle = bundleId.lowercased()
        if let match = rules.first(where: { bundle.contains($0.fragment) }) {
            return match.name
        }
        if let localized, !localized.isEmpty {
            let trimmed = localized.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased() != "app", trimmed.count > 3 {
                return trimmed
            }
        }
        return AppDisplayNameFormatter.fromBundleIdentifier(bundleId)
    }

    static func isKnownConsumerBundle(_ bundleId: String) -> Bool {
        let bundle = bundleId.lowercased()
        return rules.contains { bundle.contains($0.fragment) }
    }

    static func matches(bundleId: String, app: KnownApp) -> Bool {
        let bundle = bundleId.lowercased()
        switch app {
        case .instagram:
            return bundle.contains("instagram") || bundle.contains("burbn")
        case .tiktok:
            return bundle.contains("tiktok") || bundle.contains("musically") || bundle.contains("zhiliao")
                || bundle.contains("trill") || bundle.contains("aweme") || bundle.contains("tiktokv")
                || bundle.contains("ss.iphone")
        case .youtube:
            return bundle.contains("youtube")
        }
    }

    static func looksLikeBundleIdentifier(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return false }

        if trimmed.contains("com.") || trimmed.contains("org.") || trimmed.contains("net.") {
            let segments = trimmed.split(separator: ".").map(String.init)
            if segments.count >= 3 {
                return true
            }
        }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "."))
        if trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }),
           trimmed.contains(".") {
            return true
        }

        return false
    }

    enum KnownApp {
        case instagram
        case tiktok
        case youtube
    }
}
