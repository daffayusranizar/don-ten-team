import Foundation

/// File-based App Group storage for debug logs and shared family selection (not report payloads).
enum SessionUsageAppGroupStorage {
    static func resolvedAppGroupID() -> String {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
            ?? ScreenTimeConstants.appGroupID
    }

    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: resolvedAppGroupID())
    }

    static var containerAccessible: Bool { containerURL() != nil }

    static func listSharedFileNames() -> [String] {
        guard let url = containerURL(),
              let names = try? FileManager.default.contentsOfDirectory(atPath: url.path) else {
            return []
        }
        return names.sorted()
    }

    static func readExtensionDiagnostics() -> String? {
        guard let url = containerURL()?.appendingPathComponent("extension-diagnostics.txt"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              !text.isEmpty else {
            return nil
        }
        return text
    }
}
