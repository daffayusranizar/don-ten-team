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
                SessionResultView(
                    isAnalyzing: kidSessionViewModel.isAnalyzingSession,
                    result: kidSessionViewModel.sessionAnalysisResult,
                    errorMessage: kidSessionViewModel.sessionAnalysisError,
                    showsRecordingHint: !kidSessionViewModel.sessionIncludedScreenRecording
                ) {
                    showResult = false
                    kidSessionViewModel.resetAfterEndScreen()
                }
            }
            .onChange(of: totalSeconds) { _, newValue in
                syncDuration(to: newValue)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                handleCaptureChange()
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
            }
            .screenTimeAuthorizationAlert(isPresented: $showScreenTimeAuthAlert) {
                beginSessionAfterAuthorization()
            }
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
                StartSessionPickerView()
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

    private func beginSessionAfterAuthorization() {
        guard profileViewModel.selectedChild != nil else { return }
        kidSessionViewModel.syncSelectedChild(from: profileViewModel)
        syncDuration(to: totalSeconds)
        kidSessionViewModel.startSession(includesScreenRecording: recordScreen)
        onSessionStarted?()
        if showsBackButton {
            dismiss()
        }
    }

    private func handleCaptureChange() {
        guard recordScreen else { return }
        if UIScreen.main.isCaptured {
            guard canStartSession else { return }
            ScreenTimePermissionGate.runIfAuthorized(
                auth: familyControlsAuth,
                showAlert: { showScreenTimeAuthAlert = true },
                onAuthorized: {
                    kidSessionViewModel.syncSelectedChild(from: profileViewModel)
                    syncDuration(to: totalSeconds)
                    kidSessionViewModel.startSession(includesScreenRecording: true)
                    showActiveSession = true
                }
            )
        }
    }

}

private struct StartSessionPickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView()
        picker.preferredExtension = BroadcastConstants.extensionBundleID
        picker.showsMicrophoneButton = false
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        uiView.subviews.first?.frame = uiView.bounds
    }
}

#Preview {
    NavigationStack {
        SessionSetupView()
    }
}
