//
//  KidSessionActiveView.swift
//  team-10-c3
//

import SwiftUI
import UIKit

struct KidSessionActiveView: View {
    @Environment(\.kidSessionViewModel) private var kidSessionViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var isBroadcastLive = false

    private var showsRecordingWarning: Bool {
        kidSessionViewModel.recordingBroadcastConfirmed && !isBroadcastLive
    }

    var body: some View {
        VStack(spacing: 32) {
            HStack {
                Button(action: endSession) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .padding()
                        .background(Circle().fill(.uiSurface))
                }

                Spacer()
            }

            Spacer()

            if let child = kidSessionViewModel.selectedChild {
                ProfileAvatarView(child: child, size: 100)

                Text("\(child.name)'s Session")
                    .font(.system(size: 28, weight: .semibold))
            }

            Text(kidSessionViewModel.formattedRemainingTime)
                .font(.system(size: 64, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.primaryMediumBlue)

            Text(kidSessionViewModel.activeSessionStatusLabel)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)

            if showsRecordingWarning {
                Text(
                    "Screen recording is not active. End the session, tap Start Session, " +
                    "and confirm the system recording dialog before continuing."
                )
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            }

            Spacer()

            SecondaryButton(
                title: "End Session Early",
                size: .medium,
                action: endSession
            )
        }
        .padding(.horizontal, 30)
        .padding(.vertical)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .foregroundStyle(.textPrimary)
        .onAppear {
            refreshBroadcastLive()
            kidSessionViewModel.refreshActiveSessionClock()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshBroadcastLive()
            kidSessionViewModel.refreshActiveSessionClock()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            refreshBroadcastLive()
        }
    }

    private func refreshBroadcastLive() {
        isBroadcastLive = BroadcastCaptureStatus.isReplayKitBroadcastActive
    }

    private func endSession() {
        kidSessionViewModel.endSessionEarly()
    }
}
