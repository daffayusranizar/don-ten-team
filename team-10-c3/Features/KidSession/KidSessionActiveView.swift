//
//  KidSessionActiveView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] Child sees countdown (friendly UI)

import SwiftUI

struct KidSessionActiveView: View {
    @Environment(\.kidSessionViewModel) private var kidSessionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 32) {
            HStack {
                Button {
                    kidSessionViewModel.endSessionEarly()
                    dismiss()
                } label: {
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

            Text("Screen time in progress")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            SecondaryButton(
                title: "End Session Early",
                size: .medium,
                action: {
                    kidSessionViewModel.endSessionEarly()
                    dismiss()
                }
            )
        }
        .padding(.horizontal, 30)
        .padding(.vertical)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .foregroundStyle(.textPrimary)
        .onChange(of: kidSessionViewModel.isSessionComplete) { _, isComplete in
            if isComplete {
                dismiss()
            }
        }
        .onChange(of: kidSessionViewModel.isSessionActive) { _, isActive in
            if !isActive, !kidSessionViewModel.isSessionComplete {
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationStack {
        KidSessionActiveView()
            .environment(\.kidSessionViewModel, {
                let coordinator = SessionCoordinator(
                    sessionRepository: InMemorySessionRepository(),
                    screenTimeService: ScreenTimeService()
                )
                let viewModel = KidSessionViewModel(sessionCoordinator: coordinator)
                viewModel.selectedChild = Child(
                    name: "Raka",
                    dateOfBirth: Calendar.current.date(byAdding: .year, value: -8, to: Date()) ?? Date(),
                    gender: .boy
                )
                coordinator.remainingSeconds = 900
                coordinator.isSessionActive = true
                return viewModel
            }())
    }
}
