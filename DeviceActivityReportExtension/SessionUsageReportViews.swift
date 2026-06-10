import SwiftUI

struct SessionUsageReportView: View {
    let configuration: SessionUsageReportConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let periodTitle = configuration.periodTitle, !periodTitle.isEmpty {
                Text(periodTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if configuration.isEmpty {
                Text("No usage yet. End a session or pull to refresh.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else if !configuration.apps.isEmpty {
                SessionPerAppComparisonChart(apps: configuration.apps)
            }

            if configuration.sessionElapsedSeconds > 0 {
                Divider()
                HStack {
                    Text("Kiddly session time")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(formatDuration(configuration.sessionElapsedSeconds))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
            }

            Text("Screen Time estimate during sessions on this device.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "0s" }
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let hours = minutes / 60
        let remMinutes = minutes % 60
        if hours > 0 {
            return remMinutes > 0 ? "\(hours)h \(remMinutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}
