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
    @State private var deferredSetupTask: Task<Void, Never>?
    @State private var showScreenTimeAuthAlert = false
    @State private var showAlarmAuthAlert = false
    @State private var showSessionStartErrorAlert = false
    @State private var alarmAuthorizationState = SessionEndAlarmScheduler.displayState
    @State private var pendingSessionStartAfterAlarmAuth = false
    @State private var showActiveSession = false
    @State private var showResult = false
    @State private var broadcastObserverTask: Task<Void, Never>?
    /// Tracks App Group `broadcastActive` so we only react to false→true (user confirmed broadcast).
    @State private var extensionBroadcastWasActive = false
    /// Set when the user taps Start Session — blocks false starts from display connect / toggle alone.
    @State private var broadcastStartArmed = false
    @State private var showAddChild = false
    @State private var didInitializeDurationPickers = false

    @Environment(\.profileViewModel) private var profileViewModel
    @Environment(\.kidSessionViewModel) private var kidSessionViewModel
    @Environment(\.familyControlsAuth) private var familyControlsAuth
    @Environment(\.dismiss) private var dismiss
    private var recordingManager: RecordingManager { RecordingManager.shared }

    private var totalSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
    }

    private var canStartSession: Bool {
        profileViewModel.selectedChild != nil
            && kidSessionViewModel.canStartSession
            && totalSeconds >= SessionDurationLimits.minimumSeconds
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
                syncPlannedDurationWhenValid(totalSeconds: newValue)
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
                    RecordingManager.shared.clearSessionRecordingBinding()
                }
            }
            .onChange(of: kidSessionViewModel.phase) { _, newPhase in
                switch newPhase {
                case .idle:
                    showActiveSession = false
                    showResult = false
                case .active:
                    showResult = false
                    showActiveSession = true
                case .finished:
                    showActiveSession = false
                    showResult = true
                }
            }
            .onAppear {
                RecordingReadyBridge.startListening()
                refreshAlarmAuthorizationState()
                if !didInitializeDurationPickers {
                    hydrateDurationPickers(from: kidSessionViewModel.plannedDurationSeconds)
                    didInitializeDurationPickers = true
                }
                kidSessionViewModel.syncSelectedChild(from: profileViewModel)
                prepareForRecordingMode()

                deferredSetupTask?.cancel()
                deferredSetupTask = Task { @MainActor in
                    await Task.yield()
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled else { return }
                    familyControlsAuth.refreshAuthorizationStatus()
                    kidSessionViewModel.reconcilePersistedSession(profileViewModel: profileViewModel)
                    syncNavigationForCurrentPhase()
                    if recordScreen {
                        startBroadcastObserver()
                    }
                }
            }
            .onDisappear {
                deferredSetupTask?.cancel()
                deferredSetupTask = nil
                stopBroadcastObserver()
            }
            .alarmAuthorizationAlert(
                isPresented: $showAlarmAuthAlert,
                onAuthorized: {
                    refreshAlarmAuthorizationState()
                    resumePendingSessionStartAfterAlarmAuth()
                }
            )
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
            .onChange(of: kidSessionViewModel.sessionStartError) { _, error in
                showSessionStartErrorAlert = error != nil
            }
            .alert(
                "Could not start session",
                isPresented: $showSessionStartErrorAlert
            ) {
                Button("OK", role: .cancel) {
                    kidSessionViewModel.sessionStartError = nil
                }
            } message: {
                Text(kidSessionViewModel.sessionStartError ?? "")
            }
            .childProfileFormSheet(isPresented: $showAddChild) { child in
                profileViewModel.handleChildSaved(child)
                profileViewModel.selectedChild = child
                kidSessionViewModel.syncSelectedChild(from: profileViewModel)
            }
    }

    @ViewBuilder
    private func setupContent(profileViewModel: ProfileViewModel) -> some View {
        VStack(spacing: 18) {
            sessionToolbar

            VStack(alignment: .leading, spacing: 4) {
                Text("Choose Your Child's Profile")
                    .font(.system(size: 17, weight: .semibold))

                PrimaryDropdown(
                    selectedChild: Binding(
                        get: { profileViewModel.selectedChild },
                        set: { newChild in
                            guard !kidSessionViewModel.locksChildSelection else { return }
                            profileViewModel.selectedChild = newChild
                        }
                    ),
                    allowsSelection: !kidSessionViewModel.locksChildSelection,
                    onAddChild: { showAddChild = true }
                )
            }

            if alarmAuthorizationState != .authorized {
                SessionEndAlarmPermissionBanner(
                    authorizationState: alarmAuthorizationState,
                    onEnable: { showAlarmAuthAlert = true }
                )
            }

            if !recordScreen {
                sessionDurationSection
            }

            NotificationToggle(
                title: "Record your screen",
                isOn: $recordScreen
            )
            .padding(.top, recordScreen ? 0 : 10)
            .font(.system(size: 17, weight: .semibold))

            if recordScreen {
                ScreenBroadcastSetupGuide()
            }

            Spacer(minLength: 0)

            startSessionControl
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .padding(.horizontal, 30)
        .foregroundStyle(.textPrimary)
    }

    @ViewBuilder
    private var startSessionControl: some View {
        if recordScreen {
            ZStack {
                PrimaryButton(
                    title: "Start Session",
                    size: .large,
                    isDisabled: !canStartSession,
                    action: {}
                )
                .allowsHitTesting(false)

                StartSessionPickerView {
                    broadcastStartArmed = true
                    RecordingManager.shared.stageRecordingSessionId(UUID())
                    recordingManager.setSessionDuration(seconds: totalSeconds)
                }
                .opacity(0.011)
                .allowsHitTesting(canStartSession)
            }
            .frame(maxWidth: .infinity)
        } else {
            PrimaryButton(
                title: "Start Session",
                size: .large,
                isDisabled: !canStartSession,
                action: requestSessionStart
            )
            .frame(maxWidth: .infinity)
        }
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
                        ForEach(0..<24, id: \.self) { hour in
                            Text("\(hour) h").tag(hour)
                        }
                    }
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text("\(minute) m").tag(minute)
                        }
                    }
                    Picker("Seconds", selection: $seconds) {
                        ForEach(0..<60, id: \.self) { second in
                            Text("\(second) s").tag(second)
                        }
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 140)
                .clipped()

                Text("Minimum session length is \(SessionDurationLimits.minimumSeconds) seconds.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 32)
                    .opacity(totalSeconds < SessionDurationLimits.minimumSeconds ? 1 : 0)
                    .accessibilityHidden(totalSeconds >= SessionDurationLimits.minimumSeconds)

                VStack(alignment: .leading) {
                    Text("Quick Select")
                        .font(.system(size: 17, weight: .semibold))
                    HStack {
                        PrimaryButton(title: "15 min", size: .small) {
                            applyDuration(totalSeconds: 15 * 60)
                        }
                        Spacer()
                        PrimaryButton(title: "30 min", size: .small) {
                            applyDuration(totalSeconds: 30 * 60)
                        }
                        Spacer()
                        PrimaryButton(title: "1 hour", size: .small) {
                            applyDuration(totalSeconds: 60 * 60)
                        }
                    }
                }
                .padding(.top, 10)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func hydrateDurationPickers(from totalSeconds: Int) {
        let normalized = max(0, totalSeconds)
        hours = normalized / 3600
        minutes = (normalized % 3600) / 60
        seconds = normalized % 60
    }

    private func applyDuration(totalSeconds: Int) {
        hydrateDurationPickers(from: totalSeconds)
        let clamped = max(SessionDurationLimits.minimumSeconds, totalSeconds)
        kidSessionViewModel.setPlannedDuration(seconds: clamped)
        recordingManager.setSessionDuration(seconds: clamped)
    }

    private func syncNavigationForCurrentPhase() {
        switch kidSessionViewModel.phase {
        case .active:
            showResult = false
            showActiveSession = true
        case .finished:
            showActiveSession = false
            showResult = true
        case .idle:
            showActiveSession = false
            showResult = false
        }
    }

    private func syncPlannedDurationWhenValid(totalSeconds: Int) {
        guard totalSeconds >= SessionDurationLimits.minimumSeconds else { return }
        kidSessionViewModel.setPlannedDuration(seconds: totalSeconds)
        recordingManager.setSessionDuration(seconds: totalSeconds)
    }

    private func requestSessionStart() {
        SessionEndAlarmPermissionGate.runIfAuthorized(
            showAlert: {
                pendingSessionStartAfterAlarmAuth = true
                showAlarmAuthAlert = true
            },
            onAuthorized: {
                ScreenTimePermissionGate.runIfAuthorized(
                    auth: familyControlsAuth,
                    showAlert: { showScreenTimeAuthAlert = true },
                    onAuthorized: { beginSessionAfterAuthorization() }
                )
            }
        )
    }

    private func refreshAlarmAuthorizationState() {
        alarmAuthorizationState = SessionEndAlarmScheduler.displayState
    }

    private func resumePendingSessionStartAfterAlarmAuth() {
        guard pendingSessionStartAfterAlarmAuth else { return }
        pendingSessionStartAfterAlarmAuth = false
        if recordScreen, broadcastStartArmed {
            evaluateBroadcastAndMaybeStartSession()
        } else {
            requestSessionStart()
        }
    }

    /// Non-recording path: start immediately after Screen Time authorization.
    private func beginSessionAfterAuthorization() {
        guard profileViewModel.selectedChild != nil else { return }
        kidSessionViewModel.syncSelectedChild(from: profileViewModel)
        applyDuration(totalSeconds: totalSeconds)
        RecordingManager.shared.clearSessionRecordingBinding()
        kidSessionViewModel.startSession(
            includesScreenRecording: false,
            plannedDurationSeconds: totalSeconds
        )
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
        guard totalSeconds >= SessionDurationLimits.minimumSeconds else { return }

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

        SessionEndAlarmPermissionGate.runIfAuthorized(
            showAlert: {
                pendingSessionStartAfterAlarmAuth = true
                showAlarmAuthAlert = true
            },
            onAuthorized: {
                ScreenTimePermissionGate.runIfAuthorized(
                    auth: familyControlsAuth,
                    showAlert: { showScreenTimeAuthAlert = true },
                    onAuthorized: { beginSessionFromBroadcast() }
                )
            }
        )
    }

    private func syncExtensionBroadcastEdge() {
        extensionBroadcastWasActive = BroadcastCaptureStatus.isExtensionBroadcastActive
    }

    private func beginSessionFromBroadcast() {
        guard BroadcastCaptureStatus.isBroadcastConfirmedForSessionStart else { return }
        kidSessionViewModel.syncSelectedChild(from: profileViewModel)
        applyDuration(totalSeconds: totalSeconds)
        kidSessionViewModel.startSession(
            includesScreenRecording: true,
            recordingBroadcastConfirmed: true,
            plannedDurationSeconds: totalSeconds
        )
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

private struct ScreenBroadcastSetupGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("How to start screen broadcast", systemImage: "record.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primaryMediumBlue)

            Text(
                "Everything on your screen, including notifications, will be recorded. " +
                "Enable Do Not Disturb to prevent unexpected notifications."
            )
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                guideStep(
                    number: 1,
                    title: "Tap Start Session",
                    detail: "Use the button at the bottom of this screen."
                )
                guideStep(
                    number: 2,
                    title: "Select \(BroadcastConstants.extensionDisplayName)",
                    detail: "In the Screen Broadcast sheet, choose \(BroadcastConstants.extensionDisplayName) from the list."
                )
                guideStep(
                    number: 3,
                    title: "Tap Start Broadcast",
                    detail: "Confirm the system dialog to begin recording and your session."
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.primaryMediumBlue.opacity(0.1))
        )
    }

    private func guideStep(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.primaryMediumBlue))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
