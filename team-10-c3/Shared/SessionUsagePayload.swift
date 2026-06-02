import Foundation

public struct AppUsageRow: Codable, Sendable, Equatable, Identifiable {
    public var id: String { bundleIdentifier }
    public let displayName: String
    public let bundleIdentifier: String
    public let durationSeconds: Int

    public init(displayName: String, bundleIdentifier: String, durationSeconds: Int) {
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.durationSeconds = durationSeconds
    }
}

struct SessionUsagePayload: Codable, Sendable, Equatable {
    let childId: UUID
    let startAt: Date
    let stopAt: Date
    let totalSeconds: Int
    let apps: [AppUsageRow]

    static func encodeJSON(_ payload: SessionUsagePayload) -> String? {
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decodeJSON(_ json: String) -> SessionUsagePayload? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SessionUsagePayload.self, from: data)
    }
}
