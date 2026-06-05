//
//  AlarmAuthorizationAlert.swift
//  team-10-c3
//

import AlarmKit
import SwiftUI

extension View {
    /// Presents an alert that explains why alarms are needed, then triggers the system AlarmKit dialog.
    func alarmAuthorizationAlert(
        isPresented: Binding<Bool>,
        onAuthorized: (() -> Void)? = nil,
        onDismissWithoutAuth: (() -> Void)? = nil
    ) -> some View {
        modifier(
            AlarmAuthorizationAlertModifier(
                isPresented: isPresented,
                onAuthorized: onAuthorized,
                onDismissWithoutAuth: onDismissWithoutAuth
            )
        )
    }
}

struct SessionEndAlarmPermissionBanner: View {
    let authorizationState: SessionEndAlarmScheduler.AuthorizationDisplayState
    let onEnable: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Session alarm permission needed", systemImage: "bell.badge")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.orange)

            Text(summaryText)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            PrimaryButton(
                title: buttonTitle,
                size: .medium,
                systemImage: "bell.fill",
                action: onEnable
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.orange.opacity(0.12))
        )
    }

    private var summaryText: String {
        switch authorizationState {
        case .notDetermined:
            return "Allow Kiddly to schedule a session-end alarm so your child hears it when screen time is over — even while using other apps."
        case .denied:
            return "Alarms are turned off for Kiddly. Enable them in Settings so the session-end alarm can ring when time is up."
        case .authorized:
            return ""
        }
    }

    private var buttonTitle: String {
        authorizationState == .denied ? "Open Settings" : "Enable Session Alarm"
    }
}

private struct AlarmAuthorizationAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    var onAuthorized: (() -> Void)?
    var onDismissWithoutAuth: (() -> Void)?

    @State private var authErrorMessage: String?
    @State private var showAuthError = false

    func body(content: Content) -> some View {
        content
            .alert("Enable Session Alarm", isPresented: $isPresented) {
                Button("Not Now", role: .cancel) {
                    onDismissWithoutAuth?()
                }
                Button(continueButtonTitle) {
                    Task { await requestAlarmAccess() }
                }
            } message: {
                Text(alertMessage)
            }
            .alert("Session Alarm Access", isPresented: $showAuthError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authErrorMessage ?? "Could not enable session alarms.")
            }
    }

    private var continueButtonTitle: String {
        SessionEndAlarmScheduler.displayState == .denied ? "Open Settings" : "Continue"
    }

    private var alertMessage: String {
        switch SessionEndAlarmScheduler.displayState {
        case .denied:
            return "Kiddly needs alarm permission to ring when a session ends. Open Settings, find Kiddly, and allow alarms."
        case .notDetermined, .authorized:
            return "Kiddly schedules an alarm when your child's screen time session ends. This rings like the Clock app — even in silent mode — so they know time is up without opening Kiddly."
        }
    }

    private func requestAlarmAccess() async {
        if SessionEndAlarmScheduler.displayState == .denied {
            SessionEndAlarmScheduler.openSettings()
            return
        }

        let state = await SessionEndAlarmScheduler.requestAuthorization()
        if state == .authorized {
            onAuthorized?()
            return
        }

        if state == .denied {
            authErrorMessage = "Alarm permission was denied. Open Settings → Kiddly and allow alarms to use session-end alerts."
        } else {
            authErrorMessage = "Could not enable session alarms. Delete and reinstall the app, then try again."
        }
        showAuthError = true
    }
}
