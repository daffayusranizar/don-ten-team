import Foundation

/// Per-app seconds for one calendar hour (0–23, local time).
public struct HourlyAppUsageRow: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(hour)-\(bundleIdentifier)" }
    public let hour: Int
    public let displayName: String
    public let bundleIdentifier: String
    public let durationSeconds: Int

    public init(hour: Int, displayName: String, bundleIdentifier: String, durationSeconds: Int) {
        self.hour = min(23, max(0, hour))
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.durationSeconds = max(0, durationSeconds)
    }
}
