//
//  ScreenTimeAuthorizationAlert.swift
//  team-10-c3
//

import SwiftUI
import UIKit

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

struct ScreenTimePermissionBanner: View {
    let gaps: [ScreenTimePermissionGap]
    let statusDescription: String
    let canRequestUsageAccess: Bool
    let onEnable: () -> Void

    init(
        gaps: [ScreenTimePermissionGap],
        statusDescription: String,
        canRequestUsageAccess: Bool = true,
        onEnable: @escaping () -> Void
    ) {
        self.gaps = gaps
        self.statusDescription = statusDescription
        self.canRequestUsageAccess = canRequestUsageAccess
        self.onEnable = onEnable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Screen Time permission needed", systemImage: "hourglass.badge.plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.orange)

            Text(summaryText)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text("Status: \(statusDescription)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if canRequestUsageAccess {
                PrimaryButton(
                    title: gaps.contains(.familyControlsNotApproved)
                        ? "Enable Screen Time"
                        : "Allow App Usage",
                    size: .medium,
                    systemImage: "checkmark.shield",
                    action: onEnable
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.orange.opacity(0.12))
        )
    }

    private var summaryText: String {
        if gaps.contains(.familyControlsNotApproved) {
            return "Allow Screen Time so sessions can block every app except TikTok and YouTube."
        }
        return "Usage charts need Apple’s App & Website Usage entitlement on this TestFlight build. Sessions still work."
    }
}

private struct ScreenTimeAuthorizationAlertModifier: ViewModifier {
    @Environment(\.familyControlsAuth) private var familyControlsAuth
    @Binding var isPresented: Bool
    var onAuthorized: (() -> Void)?
    var onDismissWithoutAuth: (() -> Void)?

    @State private var authErrorMessage: String?
    @State private var showAuthError = false

    func body(content: Content) -> some View {
        content
            .alert(familyControlsAuth.permissionAlertTitle(), isPresented: $isPresented) {
                Button("Not Now", role: .cancel) {
                    onDismissWithoutAuth?()
                }
                if familyControlsAuth.isAuthorizationDenied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } else if familyControlsAuth.isUsageDataEntitlementMissing {
                    Button("OK", role: .cancel) {
                        onDismissWithoutAuth?()
                    }
                } else {
                    Button("Continue") {
                        Task { await requestScreenTimeAccess() }
                    }
                }
            } message: {
                Text(familyControlsAuth.permissionAlertMessage())
            }
            .alert("Screen Time Access", isPresented: $showAuthError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authErrorMessage ?? "Could not enable Screen Time.")
            }
    }

    private func requestScreenTimeAccess() async {
        familyControlsAuth.refreshAuthorizationStatus()
        do {
            if familyControlsAuth.missingPermissions.contains(.familyControlsNotApproved) {
                try await familyControlsAuth.ensureSessionAuthorization()
            } else {
                try await familyControlsAuth.ensureUsageAuthorization()
            }
            onAuthorized?()
        } catch {
            familyControlsAuth.refreshAuthorizationStatus()
            authErrorMessage = familyControlsAuth.sessionPermissionBlockedMessage()
                ?? error.localizedDescription
            showAuthError = true
        }
    }
}
