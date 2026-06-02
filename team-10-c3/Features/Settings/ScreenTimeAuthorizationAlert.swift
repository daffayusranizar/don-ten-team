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
            .alert("Screen Time permission", isPresented: $isPresented) {
                Button("Not Now", role: .cancel) {
                    onDismissWithoutAuth?()
                }
                Button("Continue") {
                    Task { await requestScreenTimeAccess() }
                }
            } message: {
                Text(
                    "ParentGuide needs Screen Time permission to read per-app usage for your sessions. " +
                    "Tap Continue for Apple’s permission screen, then allow access to app usage."
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
            try await familyControlsAuth.ensureUsageAuthorization()
            onAuthorized?()
        } catch {
            authErrorMessage = familyControlsAuth.recordingBlockedMessage()
                ?? error.localizedDescription
            showAuthError = true
        }
    }
}
