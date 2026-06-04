//
//  SessionSetupView.swift
//  team-10-c3
//

import SwiftUI
import ReplayKit

struct SessionSetupView: View {
    var showsBackButton: Bool = true
    var onSessionStarted: (() -> Void)?

    @State private var hours = 0
    @State private var minutes = 25
    @State private var seconds = 0
    @State private var recordScreen = false
    @State private var showScreenTimeAuthAlert = false
    @State private var showActiveSession = false
    @State private var showResult = false
    @State private var broadcastObserverTask: Task<Void, Never>?
    /// Tracks App Group `broadcastActive` so we only react to false→true (user confirmed broadcast).
    @State private var extensionBroadcastWasActive = false
    /// Set when the user taps Start Session — blocks false starts from display connect / toggle alone.
    @State private var broadcastStartArmed = false

    @Environment(\.profileViewModel) private var profileViewModel
    @Environment(\.kidSessionViewModel) private var kidSessionViewModel
    @Environment(\.familyControlsAuth) private var familyControlsAuth
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recordingManager = RecordingManager.shared

    private var totalSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
    }

    private var canStartSession: Bool {
        profileViewModel.selectedChild != nil && kidSessionViewModel.canStartSession
    }

    var body: some View {
        @Bindable var profileViewModel = profileViewModel

        setupContent(profileViewModel: profileViewModel)
            .navigationDestination(isPresented: $showActiveSession) {
                KidSessionActiveView()
            }
            .navigationDestination(isPresented: $showResult) {
                SessionResultView {
                    showResult = false
                    kidSessionViewModel.resetAfterEndScreen()
                }
            }
            .onChange(of: totalSeconds) { _, newValue in
                syncDuration(to: newValue)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                if recordScreen, BroadcastCaptureStatus.isBroadcastConfirmedForSessionStart {
                    broadcastStartArmed = true
                }
                evaluateBroadcastAndMaybeStartSession()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.didConnectNotification)) { _ in
                evaluateBroadcastAndMaybeStartSession()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.didDisconnectNotification)) { _ in
                evaluateBroadcastAndMaybeStartSession()
            }
            .onChange(of: recordScreen) { _, isEnabled in
                if isEnabled {
                    prepareForRecordingMode()
                    startBroadcastObserver()
                } else {
                    broadcastStartArmed = false
                    stopBroadcastObserver()
                }
            }
            .onChange(of: kidSessionViewModel.isSessionActive) { _, isActive in
                if isActive {
                    showActiveSession = true
                }
            }
            .onChange(of: kidSessionViewModel.isSessionComplete) { _, isComplete in
                if isComplete {
                    showResult = true
                }
            }
            .onAppear {
                RecordingReadyBridge.startListening()
                familyControlsAuth.refreshAuthorizationStatus()
                syncDuration(to: totalSeconds)
                kidSessionViewModel.syncSelectedChild(from: profileViewModel)
                prepareForRecordingMode()
                if recordScreen {
                    startBroadcastObserver()
                }
                if kidSessionViewModel.isSessionActive {
                    showActiveSession = true
                }
            }
            .onDisappear {
                stopBroadcastObserver()
            }
            .screenTimeAuthorizationAlert(
                isPresented: $showScreenTimeAuthAlert,
                onAuthorized: {
                    if recordScreen, broadcastStartArmed {
                        beginSessionFromBroadcast()
                    } else {
                        beginSessionAfterAuthorization()
                    }
                }
            )
    }

    @ViewBuilder
    private func setupContent(profileViewModel: ProfileViewModel) -> some View {
        ZStack(alignment: .top) {
            VStack(spacing: 18) {
                Color.clear
                    .frame(height: 210)

                sessionDurationSection

                NotificationToggle(
                    title: "Record your screen",
                    isOn: $recordScreen
                )
                .padding(.top, 10)
                .font(.system(size: 17, weight: .semibold))

                if recordScreen {
                    Text("Tap Start Session below, then confirm screen recording in the system dialog.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                Spacer()

                startSessionControl
            }

            sessionToolbar
                .zIndex(1001)

            VStack(alignment: .leading, spacing: 4) {
                Text("Choose Your Child's Profile")
                    .font(.system(size: 17, weight: .semibold))

                PrimaryDropdown(
                    selectedChild: Binding(
                        get: { profileViewModel.selectedChild },
                        set: { profileViewModel.selectedChild = $0 }
                    )
                )
            }
            .padding(.top, 110)
            .zIndex(1000)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .padding(.horizontal, 30)
        .foregroundStyle(.textPrimary)
    }

    @ViewBuilder
    private var startSessionControl: some View {
        ZStack {
            PrimaryButton(
                title: "Start Session",
                size: .large,
                isDisabled: !canStartSession,
                action: {}
            )
            .allowsHitTesting(false)

            if recordScreen {
                StartSessionPickerView {
                    broadcastStartArmed = true
                    RecordingManager.shared.stageRecordingSessionId(UUID())
                }
                .opacity(0.011)
                .allowsHitTesting(canStartSession)
            } else {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard canStartSession else { return }
                        requestSessionStart()
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var sessionToolbar: some View {
        ZStack {
            if showsBackButton {
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
            }

            Text("Screen Time")
                .font(.system(size: 25, weight: .bold))
        }
    }

    private var sessionDurationSection: some View {
        VStack(alignment: .leading) {
            Text("Duration")
                .font(.system(size: 17, weight: .semibold))
            VStack(alignment: .center) {
                HStack {
                    Picker("Hours", selection: $hours) {
                        ForEach(0..<24) { hour in Text("\(hour) h").tag(hour) }
                    }
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0..<60) { minute in Text("\(minute) m").tag(minute) }
                    }
                    Picker("Seconds", selection: $seconds) {
                        ForEach(0..<60) { second in Text("\(second) s").tag(second) }
                    }
                }
                .pickerStyle(.wheel)

                VStack(alignment: .leading) {
                    Text("Quick Select")
                        .font(.system(size: 17, weight: .semibold))
                    HStack {
                        PrimaryButton(title: "1 hour", size: .small) { withAnimation { hours = 1 } }
                        Spacer()
                        PrimaryButton(title: "2 hour", size: .small) { withAnimation { hours = 2 } }
                        Spacer()
                        PrimaryButton(title: "3 hour", size: .small) { withAnimation { hours = 3 } }
                    }
                }
                .padding(.top, 10)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func syncDuration(to total: Int) {
        recordingManager.setSessionDuration(minutes: max(1, total / 60))
        kidSessionViewModel.durationMinutes = max(1, total / 60)
    }

    private func requestSessionStart() {
        ScreenTimePermissionGate.runIfAuthorized(
            auth: familyControlsAuth,
            showAlert: { showScreenTimeAuthAlert = true },
            onAuthorized: { beginSessionAfterAuthorization() }
        )
    }

    /// Non-recording path: start immediately after Screen Time authorization.
    private func beginSessionAfterAuthorization() {
        guard profileViewModel.selectedChild != nil else { return }
        kidSessionViewModel.syncSelectedChild(from: profileViewModel)
        syncDuration(to: totalSeconds)
        kidSessionViewModel.startSession(includesScreenRecording: false)
        showActiveSession = true
        onSessionStarted?()
    }

    /// Resets edge detection when the record toggle changes — does not arm or start a session.
    private func prepareForRecordingMode() {
        broadcastStartArmed = false
        extensionBroadcastWasActive = BroadcastCaptureStatus.isExtensionBroadcastActive
    }

    /// Starts the session only after the user tapped Start Session and ReplayKit confirmed broadcast.
    private func evaluateBroadcastAndMaybeStartSession() {
        guard recordScreen, broadcastStartArmed else { return }

        if kidSessionViewModel.isSessionActive {
            showActiveSession = true
            syncExtensionBroadcastEdge()
            return
        }

        guard canStartSession else {
            syncExtensionBroadcastEdge()
            return
        }

        let confirmed = BroadcastCaptureStatus.isBroadcastConfirmedForSessionStart
        syncExtensionBroadcastEdge()
        guard confirmed else { return }

        ScreenTimePermissionGate.runIfAuthorized(
            auth: familyControlsAuth,
            showAlert: { showScreenTimeAuthAlert = true },
            onAuthorized: { beginSessionFromBroadcast() }
        )
    }

    private func syncExtensionBroadcastEdge() {
        extensionBroadcastWasActive = BroadcastCaptureStatus.isExtensionBroadcastActive
    }

    private func beginSessionFromBroadcast() {
        guard BroadcastCaptureStatus.isBroadcastConfirmedForSessionStart else { return }
        kidSessionViewModel.syncSelectedChild(from: profileViewModel)
        syncDuration(to: totalSeconds)
        kidSessionViewModel.startSession(
            includesScreenRecording: true,
            recordingBroadcastConfirmed: true
        )
        showActiveSession = true
    }

    /// Polls for external-display capture and extension start after the user confirms broadcast.
    private func startBroadcastObserver() {
        stopBroadcastObserver()
        guard recordScreen else { return }
        broadcastObserverTask = Task { @MainActor in
            while !Task.isCancelled {
                if recordScreen {
                    evaluateBroadcastAndMaybeStartSession()
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func stopBroadcastObserver() {
        broadcastObserverTask?.cancel()
        broadcastObserverTask = nil
    }

}

private struct StartSessionPickerView: UIViewRepresentable {
    var onStartTapped: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onStartTapped: onStartTapped)
    }

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView()
        picker.preferredExtension = BroadcastConstants.extensionBundleID
        picker.showsMicrophoneButton = false
        context.coordinator.attach(to: picker)
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        if let button = uiView.subviews.first {
            button.frame = uiView.bounds
        }
        context.coordinator.attach(to: uiView)
    }

    final class Coordinator: NSObject {
        let onStartTapped: () -> Void
        private weak var attachedButton: UIButton?

        init(onStartTapped: @escaping () -> Void) {
            self.onStartTapped = onStartTapped
        }

        func attach(to picker: RPSystemBroadcastPickerView) {
            guard let button = picker.subviews.first as? UIButton else { return }
            guard button !== attachedButton else { return }
            attachedButton?.removeTarget(self, action: #selector(startTapped), for: .touchUpInside)
            attachedButton = button
            button.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        }

        @objc private func startTapped() {
            onStartTapped()
        }
    }
}

#Preview {
    NavigationStack {
        SessionSetupView()
    }
}
