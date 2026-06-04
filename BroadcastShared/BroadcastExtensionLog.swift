//
//  BroadcastExtensionLog.swift
//  Shared between main app and ScreenRecorderExtension
//

import Foundation

/// Append-only diagnostic log written into the shared App Group container.
/// Both the extension and the main app can call `read()` to surface debug info.
public enum BroadcastExtensionLog {

    public static func append(_ message: String) {
        print(message)
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: BroadcastAppGroup.identifier
        ) else { return }
        let logURL = groupURL.appendingPathComponent(BroadcastStorageKeys.extensionDebugLog)
        let entry = "[\(Date().description)] \(message)\n"
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(Data(entry.utf8))
            handle.closeFile()
        } else {
            try? entry.write(to: logURL, atomically: true, encoding: .utf8)
        }
    }

    /// Removes the existing log file so a new session starts clean.
    public static func reset() {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: BroadcastAppGroup.identifier
        ) else { return }
        let logURL = groupURL.appendingPathComponent(BroadcastStorageKeys.extensionDebugLog)
        try? FileManager.default.removeItem(at: logURL)
    }

    /// Returns the full log text, or `nil` if the file does not exist yet.
    public static func read() -> String? {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: BroadcastAppGroup.identifier
        ) else { return nil }
        let logURL = groupURL.appendingPathComponent(BroadcastStorageKeys.extensionDebugLog)
        return try? String(contentsOf: logURL, encoding: .utf8)
    }
}
