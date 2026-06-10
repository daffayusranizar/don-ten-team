import Foundation

/// Debug-mode NDJSON logging: App Group file + HTTP ingest (Simulator → host).
enum AgentDebugLog {
    private static let sessionId = "9b8d58"
    private static let logFileName = "debug-9b8d58.ndjson"
    private static let ingestURL = URL(string: "http://127.0.0.1:7912/ingest/d23facf4-12d3-4ed3-b6a5-49e89e5bd2d0")!
    private static let queue = DispatchQueue(label: "com.team10.agentDebugLog")

    static func clearLogFile() {
        guard let url = logFileURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func log(
        hypothesisId: String,
        location: String,
        message: String,
        data: [String: String] = [:],
        runId: String = "pre-fix"
    ) {
        let entry = Entry(
            sessionId: sessionId,
            hypothesisId: hypothesisId,
            location: location,
            message: message,
            data: data,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000),
            runId: runId
        )
        guard let lineData = try? JSONEncoder().encode(entry),
              let line = String(data: lineData, encoding: .utf8) else { return }
        let ndjson = line + "\n"
        queue.async {
            appendToAppGroup(ndjson)
            postToIngest(line)
        }
    }

    /// POST lines written by the extension (extension cannot reach host ingest).
    static func relayAppGroupLogsToIngest() {
        guard let url = logFileURL(),
              let contents = try? String(contentsOf: url, encoding: .utf8) else { return }
        for line in contents.split(separator: "\n", omittingEmptySubsequences: true) {
            postToIngest(String(line))
        }
    }

    static func readLogFileContents() -> String {
        guard let url = logFileURL(),
              let contents = try? String(contentsOf: url, encoding: .utf8),
              !contents.isEmpty else {
            return "(no debug log yet — stop a session to capture)"
        }
        return contents
    }

    // MARK: - Debug UI helpers

    struct ParsedEntry: Identifiable, Sendable {
        let id: String
        let date: Date
        let hypothesisId: String
        let location: String
        let message: String
        let data: [String: String]
        let source: String
    }

    struct AppGroupSnapshot: Sendable {
        let mainAppGroupID: String
        let containerAccessible: Bool
        let containerFileListing: String
        let extensionDiagnostics: String?
    }

    struct TrustSnapshot: Sendable {
        let savedSessionElapsedSeconds: Int?
        let savedScreenTimeAppTotalSeconds: Int?
        let savedAppCount: Int?
        let selectedFilterLabel: String?
        let selectedPolicy: String?
        let selectedScore: Int?
    }

    struct PipelineStatus: Sendable {
        let screenTimeAuthorized: Bool
        let hasUsageDataAccess: Bool
        let authorizationDetail: String
        let appGroup: AppGroupSnapshot
        let trust: TrustSnapshot
        let io: IOSnapshot
        let fetchSucceeded: Bool
        let appsSaved: Bool
        let lastIssue: String?
        let entries: [ParsedEntry]
    }

    /// Latest pipeline input / raw API rows / candidates / outputs for Screen Time Debug UI.
    struct IOSnapshot: Sendable {
        let filterDetail: String?
        let inputDetail: String?
        let inputWindow: String?
        let fetchEnds: [String]
        let rawRows: [String]
        let candidates: [String]
        let selectedOutput: String?
        let finalOutput: String?
        let savedOutput: String?
    }

    static func parsedEntries() -> [ParsedEntry] {
        guard let url = logFileURL(),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return contents
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line -> ParsedEntry? in
                guard let data = String(line).data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let hypothesisId = json["hypothesisId"] as? String,
                      let location = json["location"] as? String,
                      let message = json["message"] as? String else {
                    return nil
                }
                let ts = (json["timestamp"] as? Int64) ?? (json["timestamp"] as? Int).map(Int64.init) ?? 0
                let rawData = json["data"] as? [String: String] ?? [:]
                let source = json["source"] as? String ?? "app"
                return ParsedEntry(
                    id: "\(ts)-\(location)",
                    date: Date(timeIntervalSince1970: TimeInterval(ts) / 1000),
                    hypothesisId: hypothesisId,
                    location: location,
                    message: message,
                    data: rawData,
                    source: source
                )
            }
            .sorted { $0.date > $1.date }
    }

    static func appGroupSnapshot() -> AppGroupSnapshot {
        let groupID = SessionUsageAppGroupStorage.resolvedAppGroupID()
        let containerOK = SessionUsageAppGroupStorage.containerAccessible
        let files = SessionUsageAppGroupStorage.listSharedFileNames().joined(separator: ", ")

        return AppGroupSnapshot(
            mainAppGroupID: groupID,
            containerAccessible: containerOK,
            containerFileListing: files,
            extensionDiagnostics: SessionUsageAppGroupStorage.readExtensionDiagnostics()
        )
    }

    static func ioSnapshot(from entries: [ParsedEntry]) -> IOSnapshot {
        let filter = entries.first { $0.location == "pipeline:filter" }
        let input = entries.first { $0.location == "pipeline:input" }
        let fetchEnds = entries
            .filter { $0.location == "pipeline:fetchEnd" }
            .prefix(4)
            .map { $0.data["detail"] ?? fetchEndSummary($0) }
        let rawRows = entries
            .filter { $0.location == "pipeline:rawRow" }
            .prefix(30)
            .compactMap { $0.data["line"] ?? formattedRawLine($0) }
        let candidates = entries
            .filter { $0.location == "pipeline:candidate" }
            .prefix(6)
            .map { candidateSummary($0) }
        let selected = entries.first { $0.location == "pipeline:selected" }
        let finalOutput = entries.first {
            $0.location == "pipeline:output" && $0.data["stage"] == "afterSanitize"
        } ?? entries.first { $0.location == "ScreenTimeService.fetchUsage:success" }
        let savedOutput = entries.first {
            $0.location == "pipeline:output" && $0.data["stage"] == "afterSave"
        } ?? entries.first { $0.location.contains("stopSession:afterSave") }

        return IOSnapshot(
            filterDetail: filter?.data["detail"] ?? filter?.data["filterLabel"],
            inputDetail: input?.data["detail"] ?? input?.data["filterLabels"],
            inputWindow: input.map { "\($0.data["startAt"] ?? "?") → \($0.data["stopAt"] ?? "?")" },
            fetchEnds: fetchEnds,
            rawRows: Array(rawRows),
            candidates: candidates,
            selectedOutput: selected?.data["appsList"] ?? selectedSummary(selected),
            finalOutput: finalOutput?.data["appsList"],
            savedOutput: savedOutput?.data["appsList"]
        )
    }

    private static func fetchEndSummary(_ entry: ParsedEntry) -> String {
        let label = entry.data["filterLabel"] ?? "?"
        let policy = entry.data["policy"] ?? "?"
        let apps = entry.data["uniqueApps"] ?? "0"
        let sum = entry.data["appSumSeconds"] ?? "0"
        return "[\(label) / \(policy)] \(apps) apps, \(sum)s"
    }

    private static func formattedRawLine(_ entry: ParsedEntry) -> String {
        let disposition = entry.data["disposition"] ?? "?"
        let name = entry.data["displayName"] ?? entry.data["bundleId"] ?? "?"
        let seconds = entry.data["rawSeconds"] ?? "?"
        return "\(disposition) \(name) \(seconds)s"
    }

    private static func candidateSummary(_ entry: ParsedEntry) -> String {
        let label = entry.data["filterLabel"] ?? "?"
        let policy = entry.data["policy"] ?? "?"
        let count = entry.data["appCount"] ?? "0"
        let sum = entry.data["appSumSeconds"] ?? "0"
        let list = entry.data["appsList"] ?? ""
        return "[\(label) / \(policy)] \(count) apps, \(sum)s total\n\(list)"
    }

    private static func selectedSummary(_ entry: ParsedEntry?) -> String? {
        guard let entry else { return nil }
        let label = entry.data["filterLabel"] ?? "?"
        let policy = entry.data["policy"] ?? "?"
        let score = entry.data["score"] ?? "?"
        let list = entry.data["appsList"] ?? ""
        return "score=\(score) [\(label) / \(policy)]\n\(list)"
    }

    static func trustSnapshot(from entries: [ParsedEntry]) -> TrustSnapshot {
        let save = entries.first { $0.location.contains("afterSave") }
        let selected = entries.first { $0.location.contains("aggregate:selected") }
        let fetch = entries.first { $0.location.contains("afterFetch") }
        return TrustSnapshot(
            savedSessionElapsedSeconds: save.flatMap { Int($0.data["savedTotalSeconds"] ?? "") },
            savedScreenTimeAppTotalSeconds: save.flatMap { Int($0.data["savedScreenTimeAppTotal"] ?? "") }
                ?? fetch.flatMap { Int($0.data["appSumSeconds"] ?? "") },
            savedAppCount: save.flatMap { Int($0.data["savedAppCount"] ?? "") },
            selectedFilterLabel: selected?.data["filterLabel"],
            selectedPolicy: selected?.data["policy"],
            selectedScore: selected.flatMap { Int($0.data["score"] ?? "") }
        )
    }

    static func pipelineStatus(
        screenTimeAuthorized: Bool,
        authorizationDetail: String = ""
    ) -> PipelineStatus {
        let entries = parsedEntries()
        let fetchSucceeded = entries.contains { $0.location.contains("fetchUsage:success") }
        let appsSaved = entries.contains {
            $0.location.contains("afterSave") && (Int($0.data["savedAppCount"] ?? "0") ?? 0) > 0
        }
        let trust = trustSnapshot(from: entries)
        let io = ioSnapshot(from: entries)

        let lastIssue = inferLastIssue(
            entries: entries,
            appGroup: appGroupSnapshot(),
            screenTimeAuthorized: screenTimeAuthorized
        )

        return PipelineStatus(
            screenTimeAuthorized: screenTimeAuthorized,
            hasUsageDataAccess: false,
            authorizationDetail: authorizationDetail,
            appGroup: appGroupSnapshot(),
            trust: trust,
            io: io,
            fetchSucceeded: fetchSucceeded,
            appsSaved: appsSaved,
            lastIssue: lastIssue,
            entries: entries
        )
    }

    private static func inferLastIssue(
        entries: [ParsedEntry],
        appGroup: AppGroupSnapshot,
        screenTimeAuthorized: Bool
    ) -> String? {
        if !appGroup.containerAccessible {
            return "Main app cannot access App Group container — check entitlements and provisioning profile."
        }
        if !screenTimeAuthorized {
            return "Screen Time is not authorized — enable it in Parent's Access."
        }
        if entries.isEmpty {
            return "No logs yet. Start a session, use an app, then stop."
        }
        return nil
    }

    static func hypothesisTitle(_ id: String) -> String {
        switch id {
        case "A": "Legacy report"
        case "B": "App Group"
        case "C": "Apple usage data"
        case "D": "Fetch & selection"
        case "E": "Save to storage"
        default: "Other"
        }
    }

    private struct Entry: Encodable {
        let sessionId: String
        let hypothesisId: String
        let location: String
        let message: String
        let data: [String: String]
        let timestamp: Int64
        let runId: String
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
