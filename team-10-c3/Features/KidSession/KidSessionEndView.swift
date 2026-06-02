//
//  KidSessionEndView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] Alarm + "Session Over" screen

import SwiftUI

struct KidSessionEndView: View {
    @Environment(\.kidSessionViewModel) private var kidSessionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.fill")
                .font(.system(size: 56))
                .foregroundStyle(.statusWarning)

            Text("Session Over")
                .font(.system(size: 34, weight: .bold))

            if let child = kidSessionViewModel.selectedChild {
                Text("\(child.name)'s screen time has ended.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            PrimaryButton(
                title: "Done",
                size: .large,
                action: {
                    kidSessionViewModel.resetAfterEndScreen()
                    dismiss()
                }
            )
        }
        .padding(.horizontal, 30)
        .padding(.vertical)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .foregroundStyle(.textPrimary)
    }
}

#Preview {
    NavigationStack {
        KidSessionEndView()
            .environment(\.kidSessionViewModel, KidSessionViewModel(
                sessionCoordinator: SessionCoordinator(
                    sessionRepository: InMemorySessionRepository(),
                    screenTimeService: ScreenTimeService()
                )
            ))
    }
}
