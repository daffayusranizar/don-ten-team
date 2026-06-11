//
//  DashboardSummaryViews.swift
//  team-10-c3
//
//  Created by Huy Tran on 08/06/26.
//

import DeviceActivity
import SwiftUI

// MARK: Latest Summary
@ViewBuilder
func latestSummary(
    periodTitle: String,
    reportFilter: DeviceActivityFilter?,
    reportRefreshToken: String = "",
    sessionElapsedSeconds: Int = 0,
    childName: String? = nil,
    sectionIdentity: String = ""
) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        HStack {
            Text("Latest Summary")
                .font(.system(size: 22, weight: .semibold))
            Spacer()
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .help("Session time is from Kiddly. App minutes are a Screen Time estimate.")
        }

        Group {
            if let reportFilter {
                SessionUsageReportSection(
                    context: .sessionToday,
                    filter: reportFilter,
                    refreshToken: reportRefreshToken,
                    sectionIdentity: sectionIdentity,
                    display: SessionReportDisplayPayload(
                        periodTitle: periodTitle,
                        childName: childName,
                        sessionElapsedSeconds: sessionElapsedSeconds
                    )
                )
            } else {
                VStack(spacing: 12) {
                    Text(periodTitle)
                        .font(.system(size: 17, weight: .semibold))
                    summaryEmptyState(
                        message: "No usage yet. End a session or pull to refresh."
                    )
                    if sessionElapsedSeconds > 0 {
                        Text("Kiddly session time: \(DurationFormatting.compact(seconds: sessionElapsedSeconds))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(.decorativeSkyBlue.opacity(0.13))
        }
    }
    .padding(.top, 24)
    .padding(.bottom, 8)
}

@ViewBuilder
func summaryEmptyState(message: String) -> some View {
    Text(message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 72)
}
