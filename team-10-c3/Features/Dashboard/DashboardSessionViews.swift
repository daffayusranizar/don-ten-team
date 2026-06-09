//
//  DashboardSessionViews.swift
//  team-10-c3
//
//  Created by Huy Tran on 08/06/26.
//

import SwiftUI
import Charts
import UIKit

@ViewBuilder
private func sessionControlButton(
    systemName: String,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.primaryMediumBlue)
            .frame(width: 40, height: 40)
            .background(.white, in: Circle())
    }
    .buttonStyle(.plain)
}

// MARK: Current Screen Time (active session only)
@ViewBuilder
func currentScreenTimeView(
    coordinator: SessionCoordinator,
    addingTime: Binding<Bool>,
    onStop: @escaping () -> Void
) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Active Session")
            .font(.system(size: 20, weight: .semibold))

        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(coordinator.formattedSessionRemaining) left")
                    .font(.system(size: 34, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("Used · \(coordinator.formattedSessionElapsed)")
                    .font(.system(size: 14, weight: .medium))
                    .opacity(0.85)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                sessionControlButton(systemName: "stop.fill", action: onStop)

                sessionControlButton(
                    systemName: coordinator.isSessionPaused ? "play.fill" : "pause.fill"
                ) {
                    withAnimation(.snappy) {
                        coordinator.togglePause()
                    }
                }
            }
            .fixedSize()
        }

        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .foregroundStyle(.white)

                Capsule()
                    .frame(width: max(0, geometry.size.width * coordinator.sessionProgress))
                    .foregroundStyle(.primaryTeal)
            }
        }
        .frame(height: 11)

        Text("Time Limit \(coordinator.formattedVerboseTimeLimit)")
            .font(.system(size: 10, weight: .regular))

        screenTimeActionButton(title: "Add More Time") {
            addingTime.wrappedValue = true
        }
        .padding(.top, 4)
    }
    .padding(.horizontal, 27)
    .padding(.vertical, 25)
    .foregroundStyle(.white)
    .background(.primaryMediumBlue)
    .clipShape(RoundedRectangle(cornerRadius: 25.6))
    .padding(.top, 30)
}

// MARK: Last Screen Time (session ended or no session today)
@ViewBuilder
func lastScreenTimeView(
    coordinator: SessionCoordinator,
    onStartSession: @escaping () -> Void
) -> some View {
    let hasData = coordinator.latestTotalSeconds > 0
    let total = hasData
        ? coordinator.formattedLatestBannerTotal
        : "—"

    let progressLabel: String = {
        if hasData {
            return "\(Int(coordinator.latestBannerProgress * 100))% of the session"
        }
        return "Start a session to track screen time"
    }()

    screenTimeBannerView(
        title: "Last Session",
        total: total,
        progress: hasData ? coordinator.latestBannerProgress : 0,
        progressLabel: progressLabel
    ) {
        screenTimeActionButton(title: "Start Session", action: onStartSession)
    }
}

@ViewBuilder
private func screenTimeActionButton(title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(.white))
    }
    .buttonStyle(.plain)
}

@ViewBuilder
private func screenTimeBannerView<Footer: View>(
    title: String,
    total: String,
    progress: Double,
    progressLabel: String,
    @ViewBuilder footer: () -> Footer = { EmptyView() }
) -> some View {
    VStack(alignment: .leading, spacing: 15) {
        Text(title)
            .font(Font.system(size: 24, weight: .semibold))

        Text("Total")

        Text(total)
            .font(Font.system(size: 40, weight: .semibold))

        VStack(alignment: .leading) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .foregroundStyle(.white)

                    Capsule()
                        .frame(width: geometry.size.width * progress)
                        .foregroundStyle(.primaryTeal)
                }
            }
            .frame(height: 12)

            Text(progressLabel)
        }

        footer()
    }
    .padding(.horizontal, 30)
    .padding(.vertical, 25)
    .foregroundStyle(.white)
    .background(.primaryMediumBlue)
    .clipShape(
        RoundedRectangle(cornerRadius: 25)
    )
    .padding(.top, 30)
}
