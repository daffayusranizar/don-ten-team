#if DEBUG
import SwiftUI
import FamilyControls

struct ScreenTimeDebugView: View {
    @Environment(\.familyControlsAuth) private var familyControlsAuth
    @State private var status = AgentDebugLog.pipelineStatus(screenTimeAuthorized: false)
    @State private var showRawLog = false
    @State private var copiedToast = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                checklistSection
                ioSection
                trustSection
                if let issue = status.lastIssue {
                    issueBanner(issue)
                }
                appGroupSection
                timelineSection
                rawLogSection
            }
            .padding()
        }
        .navigationTitle("Screen Time Debug")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .overlay(alignment: .bottom) {
            if copiedToast {
                Text("Copied to clipboard")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.textPrimary))
                    .foregroundStyle(.white)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear { refresh() }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Pipeline debugger", systemImage: "ladybug.fill")
                .font(.headline)
            Text("Run a session → stop → tap Refresh. Input/output tables below; same lines print in Xcode console as [ScreenTime:…].")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var checklistSection: some View {
        VStack(spacing: 10) {
            statusRow(
                title: "Screen Time authorized",
                ok: status.screenTimeAuthorized,
                detail: status.authorizationDetail
            )
            statusRow(
                title: "Usage data access",
                ok: status.hasUsageDataAccess,
                detail: status.hasUsageDataAccess
                    ? "approvedWithDataAccess (required for per-app usage)"
                    : "Only basic approval — re-authorize after adding App & Website Usage capability"
            )
            statusRow(
                title: "App Group container",
                ok: status.appGroup.containerAccessible,
                detail: status.appGroup.mainAppGroupID
            )
            statusRow(
                title: "activityData fetch",
                ok: status.fetchSucceeded,
                detail: status.fetchSucceeded
                    ? "DeviceActivityData.activityData succeeded"
                    : "No success log — check usage data access or EU region"
            )
            statusRow(
                title: "Apps saved",
                ok: status.appsSaved,
                detail: status.appsSaved ? "Non-empty app list in snapshot" : "Saved with 0 apps or not saved"
            )
        }
        .padding()
        .background(cardBackground)
    }

    private var ioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Input / output (last session)")

            ioBlock(
                title: "FILTER (hourly+session)",
                body: status.io.filterDetail ?? "—"
            )

            ioBlock(
                title: "INPUT (fetch window)",
                body: status.io.inputDetail ?? status.io.inputWindow ?? "—"
            )

            ioBlock(
                title: "FETCH END (live + cached)",
                body: status.io.fetchEnds.isEmpty
                    ? "—"
                    : status.io.fetchEnds.joined(separator: "\n\n—\n\n")
            )

            ioBlock(
                title: "RAW API rows (per segment, newest 30)",
                body: status.io.rawRows.isEmpty
                    ? "—"
                    : status.io.rawRows.joined(separator: "\n")
            )

            ioBlock(
                title: "CANDIDATES (each filter × policy)",
                body: status.io.candidates.isEmpty
                    ? "—"
                    : status.io.candidates.joined(separator: "\n\n—\n\n")
            )

            ioBlock(
                title: "OUTPUT — selected payload",
                body: status.io.selectedOutput ?? "—"
            )

            ioBlock(
                title: "OUTPUT — after sanitize (fetch result)",
                body: status.io.finalOutput ?? "—"
            )

            ioBlock(
                title: "OUTPUT — saved snapshot (noise-filtered)",
                body: status.io.savedOutput ?? "—"
            )
        }
        .padding()
        .background(cardBackground)
    }

    private func ioBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primaryMediumBlue)
            Text(body)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private var trustSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Trust totals")

            keyValue(
                "Session elapsed (saved)",
                formatSeconds(status.trust.savedSessionElapsedSeconds)
            )
            keyValue(
                "Screen Time app sum",
                formatSeconds(status.trust.savedScreenTimeAppTotalSeconds)
            )
            keyValue("Saved app count", status.trust.savedAppCount.map(String.init) ?? "—")

            #if DEBUG
            keyValue(
                "Noise rows filtered (last fetch)",
                String(SessionUsageNoiseFilter.lastDroppedNoiseCount)
            )
            keyValue(
                "Uniform-duration rejected",
                ScreenTimePayloadSelector.lastUniformDurationRejected ? "yes" : "no"
            )
            #endif

            if let selection = DeviceActivityUsageAggregator.lastPayloadSelection {
                keyValue("Selected filter", selection.filterLabel)
                keyValue("Selected policy", selection.policy)
                keyValue("Selector score", String(selection.score))
                keyValue("Selected app sum", "\(selection.appSumSeconds)s (\(selection.appCount) apps)")
            } else if let label = status.trust.selectedFilterLabel {
                keyValue("Selected filter", label)
                keyValue("Selected policy", status.trust.selectedPolicy ?? "—")
                keyValue("Selector score", status.trust.selectedScore.map(String.init) ?? "—")
            } else {
                Text("No payload selected yet — stop a session on device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(cardBackground)
    }

    private var appGroupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Live App Group")

            keyValue("Bundle", Bundle.main.bundleIdentifier ?? "—")
            keyValue(
                "App Group files",
                status.appGroup.containerFileListing.isEmpty
                    ? "(empty)"
                    : status.appGroup.containerFileListing
            )
            if let diagnostics = status.appGroup.extensionDiagnostics {
                keyValue("Legacy diagnostics", diagnostics)
            }
        }
        .padding()
        .background(cardBackground)
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Event timeline (\(status.entries.count))")

            if status.entries.isEmpty {
                Text("No events yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(status.entries) { entry in
                    timelineRow(entry)
                }
            }
        }
        .padding()
        .background(cardBackground)
    }

    private var rawLogSection: some View {
        DisclosureGroup("Raw NDJSON", isExpanded: $showRawLog) {
            Text(AgentDebugLog.readLogFileContents())
                .font(.system(.caption2, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(.top, 8)
        }
        .padding()
        .background(cardBackground)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { refresh() } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Button { copyReport() } label: {
                    Label("Copy report", systemImage: "doc.on.doc")
                }
                Button(role: .destructive) {
                    AgentDebugLog.clearLogFile()
                    refresh()
                } label: {
                    Label("Clear log", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Components

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.primarySoftPurple.opacity(0.15))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
    }

    private func statusRow(title: String, ok: Bool, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func issueBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.orange.opacity(0.12))
        )
    }

    private func timelineRow(_ entry: AgentDebugLog.ParsedEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Self.timeFormatter.string(from: entry.date))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.source == "extension" ? "EXT" : "APP")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(entry.source == "extension" ? .blue.opacity(0.2) : .gray.opacity(0.2)))
            }
            Text(AgentDebugLog.hypothesisTitle(entry.hypothesisId))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primarySoftPurple)
            Text(entry.message)
                .font(.subheadline)
            if !entry.data.isEmpty {
                Text(entry.data.map { "\($0.key): \($0.value)" }.sorted().joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.caption.weight(.semibold))
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Actions

    private func refresh() {
        familyControlsAuth.refreshAuthorizationStatus()
        status = AgentDebugLog.pipelineStatus(
            screenTimeAuthorized: familyControlsAuth.isAuthorized,
            hasUsageDataAccess: familyControlsAuth.hasUsageDataAccess,
            authorizationDetail: familyControlsAuth.authorizationStatusDescription
        )
    }

    private func copyReport() {
        var lines: [String] = ["Screen Time Debug Report", ""]
        lines.append("Authorized: \(status.screenTimeAuthorized)")
        lines.append("Usage data access: \(status.hasUsageDataAccess) (\(status.authorizationDetail))")
        lines.append("Session elapsed: \(formatSeconds(status.trust.savedSessionElapsedSeconds))")
        lines.append("App sum: \(formatSeconds(status.trust.savedScreenTimeAppTotalSeconds))")
        if let selection = DeviceActivityUsageAggregator.lastPayloadSelection {
            lines.append("Selected: \(selection.filterLabel) / \(selection.policy) score=\(selection.score)")
        }
        lines.append("")
        lines.append("=== FILTER ===")
        lines.append(status.io.filterDetail ?? "—")
        lines.append("")
        lines.append("=== INPUT ===")
        lines.append(status.io.inputDetail ?? status.io.inputWindow ?? "—")
        lines.append("")
        lines.append("=== FETCH END ===")
        lines.append(status.io.fetchEnds.isEmpty ? "—" : status.io.fetchEnds.joined(separator: "\n\n"))
        lines.append("")
        lines.append("=== RAW ROWS ===")
        lines.append(status.io.rawRows.isEmpty ? "—" : status.io.rawRows.joined(separator: "\n"))
        lines.append("")
        lines.append("=== SELECTED ===")
        lines.append(status.io.selectedOutput ?? "—")
        lines.append("")
        lines.append("=== FINAL ===")
        lines.append(status.io.finalOutput ?? "—")
        lines.append("")
        lines.append("=== SAVED ===")
        lines.append(status.io.savedOutput ?? "—")
        lines.append("")
        lines.append("App Group: \(status.appGroup.mainAppGroupID)")
        lines.append("Container OK: \(status.appGroup.containerAccessible)")
        if let issue = status.lastIssue { lines.append("Issue: \(issue)") }
        lines.append("")
        for entry in status.entries.reversed() {
            lines.append("[\(entry.source)] \(entry.location): \(entry.message)")
            if !entry.data.isEmpty {
                lines.append("  \(entry.data)")
            }
        }
        lines.append("")
        lines.append(AgentDebugLog.readLogFileContents())
        UIPasteboard.general.string = lines.joined(separator: "\n")
        withAnimation { copiedToast = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation { copiedToast = false }
            }
        }
    }

    private func formatSeconds(_ value: Int?) -> String {
        guard let value else { return "—" }
        return DurationFormatting.compact(seconds: value)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ScreenTimeDebugView()
    }
}
#endif
