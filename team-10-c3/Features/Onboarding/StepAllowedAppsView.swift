//
//  StepAllowedAppsView.swift
//  team-10-c3
//

import SwiftUI

struct StepAllowedAppsView: View {
    @Binding var data: OnboardingData

    @Environment(\.familyControlsAuth) private var familyControlsAuth
    @State private var goToReviewPage = false
    @State private var showScreenTimeAuthAlert = false
    @State private var allowedAppCount = 0

    private var canContinue: Bool {
        familyControlsAuth.isAuthorized && allowedAppCount > 0
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.primaryDarkBlue, .blue],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.shield")
                    .foregroundStyle(.white)
                    .font(.system(size: 30))
            }

            VStack(spacing: 5) {
                Text("Choose Allowed Apps")
                    .font(.system(size: 20, weight: .semibold))
                Text("Pick which apps your child can use during a session. Everything else stays blocked until the session ends.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if familyControlsAuth.needsPermissionPrompt {
                PrimaryButton(
                    title: "Enable Screen Time",
                    size: .medium,
                    systemImage: "hourglass.badge.plus",
                    action: { showScreenTimeAuthAlert = true }
                )
            }

            FamilyActivityPickerSection(
                onRequireScreenTimeAuth: { showScreenTimeAuthAlert = true },
                onSelectionChanged: { _ in
                    allowedAppCount = FamilyActivitySelectionStore.allowedAppCount
                }
            )
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(.primaryMediumBlue)
                        .opacity(0.12)
                )

            Spacer()

            VStack(spacing: 15) {
                PrimaryButton(
                    title: "Continue",
                    isDisabled: !canContinue,
                    action: { goToReviewPage = true }
                )

                Button {
                    goToReviewPage = true
                } label: {
                    Text("Set Up Later")
                        .foregroundStyle(.textSecondary)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .foregroundStyle(.textPrimary)
        .padding(.horizontal, 30)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(OnboardingProgress.allowedAppsTitle)
                    .foregroundStyle(.textSecondary)
                    .font(.system(size: 22, weight: .semibold))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToReviewPage) {
            ReviewView(data: $data)
        }
        .screenTimeAuthorizationAlert(isPresented: $showScreenTimeAuthAlert) {
            familyControlsAuth.refreshAuthorizationStatus()
            allowedAppCount = FamilyActivitySelectionStore.allowedAppCount
        }
        .onAppear {
            familyControlsAuth.refreshAuthorizationStatus()
            allowedAppCount = FamilyActivitySelectionStore.allowedAppCount
        }
    }
}

#Preview {
    NavigationStack {
        StepAllowedAppsView(data: .constant(OnboardingData()))
    }
    .environment(\.familyControlsAuth, FamilyControlsAuthService())
}
