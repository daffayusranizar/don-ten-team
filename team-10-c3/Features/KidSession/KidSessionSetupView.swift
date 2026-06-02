//
//  KidSessionSetupView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] Parent picks profile + duration

import SwiftUI

struct KidSessionSetupView: View {
    @Environment(\.kidSessionViewModel) private var kidSessionViewModel
    @Environment(\.profileViewModel) private var profileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showActiveSession = false

    private var genderLabel: String {
        guard let gender = kidSessionViewModel.selectedChild?.gender else { return "" }
        switch gender {
        case .boy: return "Male"
        case .girl: return "Female"
        case .preferNotToSay: return "Prefer not to say"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                toolbar

                if let child = kidSessionViewModel.selectedChild {
                    ProfileAvatarView(child: child, size: 120)

                    VStack(spacing: 8) {
                        Text(child.name)
                            .font(.system(size: 30, weight: .medium))

                        Text("Age \(child.currentAge) | \(genderLabel)")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Session Duration")
                            .font(.system(size: 20, weight: .semibold))

                        HStack(spacing: 12) {
                            ForEach(kidSessionViewModel.durationOptions, id: \.self) { minutes in
                                Button {
                                    kidSessionViewModel.durationMinutes = minutes
                                } label: {
                                    Text("\(minutes)m")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(
                                            kidSessionViewModel.durationMinutes == minutes
                                            ? .white
                                            : .textPrimary
                                        )
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            Capsule()
                                                .fill(
                                                    kidSessionViewModel.durationMinutes == minutes
                                                    ? Color.primaryMediumBlue
                                                    : Color.uiSurface
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(.primarySoftPurple)
                            .opacity(0.2)
                    )

                    PrimaryButton(
                        title: "Start Session",
                        size: .large,
                        systemImage: "play.fill",
                        isDisabled: !kidSessionViewModel.canStartSession,
                        action: startSession
                    )
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .foregroundStyle(.textPrimary)
        .onAppear {
            kidSessionViewModel.syncSelectedChild(from: profileViewModel)
        }
        .navigationDestination(isPresented: $showActiveSession) {
            KidSessionActiveView()
        }
        .navigationDestination(isPresented: Binding(
            get: { kidSessionViewModel.isSessionComplete },
            set: { isPresented in
                if !isPresented {
                    kidSessionViewModel.resetAfterEndScreen()
                }
            }
        )) {
            KidSessionEndView()
        }
    }

    private var toolbar: some View {
        ZStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .padding()
                        .background(Circle().fill(.uiSurface))
                }

                Spacer()
            }

            Text("Kid Session")
                .font(.system(size: 25, weight: .bold))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.primaryMediumBlue)

            Text("Select a child on the dashboard before starting a session.")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    private func startSession() {
        kidSessionViewModel.startSession()
        showActiveSession = true
    }
}

#Preview {
    NavigationStack {
        KidSessionSetupView()
            .environment(\.kidSessionViewModel, KidSessionViewModel(
                sessionCoordinator: SessionCoordinator(
                    sessionRepository: InMemorySessionRepository(),
                    screenTimeService: ScreenTimeService()
                )
            ))
    }
}
