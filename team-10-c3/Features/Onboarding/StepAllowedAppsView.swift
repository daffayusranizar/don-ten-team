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

    private var canContinue: Bool {
        familyControlsAuth.isAuthorized && FamilyActivitySelectionStore.hasAllowedApps
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
                Text("During a session, only TikTok and YouTube stay open. Pick them here so Kiddly can block everything else.")
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

            FamilyActivityPickerSection(onRequireScreenTimeAuth: { showScreenTimeAuthAlert = true })
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
                Text("Step 6 of 6")
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
        }
        .onAppear {
            familyControlsAuth.refreshAuthorizationStatus()
        }
    }
}

#Preview {
    NavigationStack {
        StepAllowedAppsView(data: .constant(OnboardingData()))
    }
    .environment(\.familyControlsAuth, FamilyControlsAuthService())
}
