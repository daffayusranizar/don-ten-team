//
//  ScreenTimeAuthorizationAlert.swift
//  team-10-c3
//

import SwiftUI

extension View {
    /// Presents an alert that triggers the system Screen Time permission dialog.
    func screenTimeAuthorizationAlert(
        isPresented: Binding<Bool>,
        onAuthorized: (() -> Void)? = nil,
        onDismissWithoutAuth: (() -> Void)? = nil
    ) -> some View {
        modifier(
            ScreenTimeAuthorizationAlertModifier(
                isPresented: isPresented,
                onAuthorized: onAuthorized,
                onDismissWithoutAuth: onDismissWithoutAuth
            )
        )
    }
}

private struct ScreenTimeAuthorizationAlertModifier: ViewModifier {
    @Environment(FamilyControlsAuthService.self) private var familyControlsAuth
    @Binding var isPresented: Bool
    var onAuthorized: (() -> Void)?
    var onDismissWithoutAuth: (() -> Void)?

    @State private var authErrorMessage: String?
    @State private var showAuthError = false

    func body(content: Content) -> some View {
        content
            .alert("Enable Screen Time", isPresented: $isPresented) {
                Button("Not Now", role: .cancel) {
                    onDismissWithoutAuth?()
                }
                Button("Enable") {
                    Task { await requestScreenTimeAccess() }
                }
            } message: {
                Text(
                    "Allow Screen Time access so the app can show per-app usage after each session. " +
                    "Apple will ask you to confirm on the next screen."
                )
            }
            .alert("Screen Time Access", isPresented: $showAuthError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authErrorMessage ?? "Could not enable Screen Time.")
            }
    }

    private func requestScreenTimeAccess() async {
        do {
            try await familyControlsAuth.requestAuthorization()
            familyControlsAuth.refreshAuthorizationStatus()
            if familyControlsAuth.canRecordSessionUsage {
                onAuthorized?()
            } else {
                authErrorMessage = familyControlsAuth.recordingBlockedMessage()
                    ?? "Screen Time access was not granted. Try again in Parent's Access."
                showAuthError = true
            }
        } catch {
            authErrorMessage = error.localizedDescription
            showAuthError = true
        }
    }
}
