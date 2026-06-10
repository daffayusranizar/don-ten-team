import SwiftUI

/// Horizontal bar chart comparing Screen Time per allowed app (no axis).
struct SessionPerAppComparisonChart: View {
    let apps: [SessionUsageReportConfiguration.AppRow]

    private static let iconColumnWidth: CGFloat = 28
    private static let rowSpacing: CGFloat = 12
    private static let barHeight: CGFloat = 10

    private var displayApps: [SessionUsageReportConfiguration.AppRow] {
        Array(apps.prefix(5))
    }

    private var maxSeconds: Int {
        max(displayApps.map(\.durationSeconds).max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Compare by app")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: Self.rowSpacing) {
                ForEach(displayApps) { app in
                    appRow(app)
                }
            }
        }
    }

    private func appRow(_ app: SessionUsageReportConfiguration.AppRow) -> some View {
        HStack(alignment: .center, spacing: 8) {
            ApplicationTokenIcon(token: app.applicationToken, size: 22)
                .frame(width: Self.iconColumnWidth)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(app.displayName)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(formatDuration(app.durationSeconds))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                GeometryReader { geometry in
                    let fillWidth = geometry.size.width * CGFloat(app.durationSeconds) / CGFloat(maxSeconds)

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.12))
                        Capsule()
                            .fill(app.color)
                            .frame(width: max(4, fillWidth))
                    }
                }
                .frame(height: Self.barHeight)
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "0s" }
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let hours = minutes / 60
        let remMinutes = minutes % 60
        if hours > 0 {
            return remMinutes > 0 ? "\(hours)h \(remMinutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}
