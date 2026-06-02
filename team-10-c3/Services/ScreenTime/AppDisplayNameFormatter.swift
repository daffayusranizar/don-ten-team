import Foundation

enum AppDisplayNameFormatter {
    private static let genericSegments: Set<String> = [
        "ios", "iphoneos", "appex", "extension", "service", "ui", "app", "mobile",
    ]

    static func fromBundleIdentifier(_ bundleId: String) -> String {
        let parts = bundleId.split(separator: ".").map(String.init)
        guard !parts.isEmpty else { return bundleId }

        for part in parts.reversed() {
            let lower = part.lowercased()
            if genericSegments.contains(lower) || lower.hasSuffix("service") {
                continue
            }
            if part.count >= 3 {
                return prettify(part)
            }
        }

        let last = parts.last ?? bundleId
        return prettify(last)
    }

    private static func prettify(_ raw: String) -> String {
        let spaced = raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        guard !spaced.isEmpty else { return raw }
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }
}
