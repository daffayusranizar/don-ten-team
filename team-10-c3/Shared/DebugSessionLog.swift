import Foundation

/// Debug session `fcc95f`: App Group NDJSON + host ingest (simulator / relay).
enum DebugSessionLog {
    private static let sessionId = "fcc95f"
    private static let logFileName = "debug-fcc95f.ndjson"
    private static let ingestURL = URL(string: "http://127.0.0.1:7912/ingest/d23facf4-12d3-4ed3-b6a5-49e89e5bd2d0")!
    private static let queue = DispatchQueue(label: "com.team10.debugSessionLog.fcc95f")

    enum BuildChannel: String {
        case debug
        case testFlight
        case appStore
        case unknown
    }

    static var buildChannel: BuildChannel {
        #if DEBUG
        return .debug
        #else
        guard let receipt = Bundle.main.appStoreReceiptURL else { return .unknown }
        switch receipt.lastPathComponent {
        case "sandboxReceipt": return .testFlight
        case "receipt": return .appStore
        default: return .unknown
        }
        #endif
    }

    /// Reads embedded.mobileprovision ASCII for entitlement keys (dev/ad-hoc only; absent on TestFlight).
    static func embeddedProfileContains(_ needle: String) -> Bool? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return nil }
        let ascii = String(data: data, encoding: .ascii) ?? ""
        return ascii.contains(needle)
    }

    static func log(
        hypothesisId: String,
        location: String,
        message: String,
        data: [String: String] = [:],
        runId: String = "pre-fix"
    ) {
        let payload: [String: Any] = [
            "sessionId": sessionId,
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "data": data,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "runId": runId,
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let lineData = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: lineData, encoding: .utf8) else { return }
        let ndjson = line + "\n"
        queue.async {
            appendToAppGroup(ndjson)
            postToIngest(line)
        }
    }

    static func readAppGroupContents() -> String {
        guard let url = logFileURL(),
              let contents = try? String(contentsOf: url, encoding: .utf8),
              !contents.isEmpty else {
            return "(empty)"
        }
        return contents
    }

    static func clearAppGroupLog() {
        guard let url = logFileURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func logFileURL() -> URL? {
        SessionUsageAppGroupStorage.containerURL()?.appendingPathComponent(logFileName)
    }

    private static func appendToAppGroup(_ ndjson: String) {
        guard let url = logFileURL() else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            try? handle.seekToEnd()
            if let data = ndjson.data(using: .utf8) {
                try? handle.write(contentsOf: data)
            }
        } else {
            try? ndjson.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private static func postToIngest(_ jsonLine: String) {
        var request = URLRequest(url: ingestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "X-Debug-Session-Id")
        request.httpBody = jsonLine.data(using: .utf8)
        URLSession.shared.dataTask(with: request).resume()
    }
}
