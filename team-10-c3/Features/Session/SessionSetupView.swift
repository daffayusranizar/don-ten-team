//
//  SessionSetupView.swift
//  team-10-c3
//
//  Created by Huy Tran on 02/06/26.
//

import SwiftUI
import Combine
import ReplayKit

// MARK: - Session Setup View

struct SessionSetupView: View {
    @State var hours = 0
    @State var minutes = 25 // defaults to 25 minutes
    @State var seconds = 0

    var totalSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
    }

    @State var recordScreen: Bool = false

    @Environment(\.profileViewModel) private var profileViewModel
    @Environment(\.kidSessionViewModel) private var kidSessionViewModel

    // MARK: Recording + Pipeline State
    @StateObject private var recordingManager = RecordingManager.shared
    @State private var showActiveSession = false
    @State private var pipelineResult: PipelineResult? = nil
    @State private var errorMessage: String? = nil
    @State private var showResult = false
    @State private var isProcessing = false

    var body: some View {
        @Bindable var profileViewModel = profileViewModel

        setupContent(profileViewModel: profileViewModel)
            // Navigate to KidSessionActiveView when recording starts
            .navigationDestination(isPresented: $showActiveSession) {
                KidSessionActiveView()
            }
            // Navigate to KidSessionEndView when session completes
            .navigationDestination(isPresented: Binding(
                get: { kidSessionViewModel.isSessionComplete && !showResult },
                set: { if !$0 { kidSessionViewModel.resetAfterEndScreen() } }
            )) {
                KidSessionEndView()
            }
            // Navigate to result view after pipeline finishes
            .navigationDestination(isPresented: $showResult) {
                SessionResultView(
                    result: pipelineResult,
                    errorMessage: errorMessage
                ) {
                    pipelineResult = nil
                    errorMessage = nil
                    showResult = false
                    kidSessionViewModel.resetAfterEndScreen()
                }
            }
            // Sync duration with the broadcast extension and KidSessionViewModel
            .onChange(of: totalSeconds) { _, newValue in
                recordingManager.setSessionDuration(minutes: newValue / 60)
                kidSessionViewModel.durationMinutes = max(1, newValue / 60)
            }
            // Detect iOS screen capture start/stop
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                handleCaptureChange()
            }
            // Darwin signal from extension when recording file is ready
            .onReceive(NotificationCenter.default.publisher(for: RecordingReadyBridge.notification)) { _ in
                guard isProcessing else { return }
                Task { await runPipeline() }
            }
            // When session completes, kick off the AI pipeline
            .onChange(of: kidSessionViewModel.isSessionComplete) { _, isComplete in
                if isComplete {
                    isProcessing = true
                    // Fallback: if Darwin signal doesn't fire within 10s, run pipeline anyway
                    Task {
                        try? await Task.sleep(for: .seconds(10))
                        if isProcessing { await runPipeline() }
                    }
                }
            }
            .onAppear {
                RecordingReadyBridge.startListening()
                recordingManager.setSessionDuration(minutes: totalSeconds / 60)
                kidSessionViewModel.durationMinutes = max(1, totalSeconds / 60)
                kidSessionViewModel.syncSelectedChild(from: profileViewModel)
            }
    }

    // MARK: - Setup Step (layout unchanged)

    @ViewBuilder
    private func setupContent(profileViewModel: ProfileViewModel) -> some View {
        ZStack(alignment: .top) {
            VStack(spacing: 18) {
                Color.clear
                    .frame(height: 210)

                durationSection(hours: $hours, minutes: $minutes, seconds: $seconds)

                NotificationToggle(
                    title: "Record your screen",
                    isOn: $recordScreen
                )
                .padding(.top, 10)
                .font(.system(size: 17, weight: .semibold))

                Spacer()

                // ZStack: PrimaryButton provides the visual design; StartSessionPickerView
                // sits on top and handles all touches to trigger the system broadcast picker.
                ZStack {
                    PrimaryButton(title: "Start Session", size: .large) {}
                        .allowsHitTesting(false)
                    StartSessionPickerView()
                        .opacity(0.011)
                }
                .frame(maxWidth: .infinity)
            }

            toolBar()
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

    // MARK: - Capture Detection

    private func handleCaptureChange() {
        if UIScreen.main.isCaptured {
            // Recording started — sync child + duration into KidSessionViewModel, start timer, push view
            kidSessionViewModel.syncSelectedChild(from: profileViewModel)
            kidSessionViewModel.durationMinutes = max(1, totalSeconds / 60)
            kidSessionViewModel.startSession()
            showActiveSession = true
        }
        // Recording stopped: extension is writing the file.
        // Pipeline is triggered by Darwin "recordingReady" signal or the 10s fallback
        // in onChange(kidSessionViewModel.isSessionComplete).
    }

    // MARK: - AI Pipeline

    @MainActor
    private func runPipeline() async {
        guard isProcessing else { return }
        isProcessing = false

        guard let videoURL = findRecordingFile() else {
            errorMessage = "No recording found in App Group '\(recordingManager.appGroupIdentifier)'."
            showResult = true
            return
        }
        do {
            let orchestrator = PipelineOrchestrator()
            let output = try await orchestrator.processSession(videoURL: videoURL)
            pipelineResult = PipelineResult(from: output)
        } catch {
            errorMessage = error.localizedDescription
        }
        showResult = true
    }

    private func findRecordingFile() -> URL? {
        let fm = FileManager.default
        if let path = recordingManager.fetchLatestRecordedVideoPath() {
            let url = URL(fileURLWithPath: path)
            if fm.fileExists(atPath: url.path) { return url }
        }
        guard let container = fm.containerURL(forSecurityApplicationGroupIdentifier: recordingManager.appGroupIdentifier) else { return nil }
        let files = (try? fm.contentsOfDirectory(at: container, includingPropertiesForKeys: [.contentModificationDateKey], options: [])) ?? []
        return files
            .filter { $0.pathExtension == "mp4" }
            .filter { (try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0 > 1000 }
            .sorted {
                let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return d1 > d2
            }
            .first
    }

    // MARK: - Helpers

    private func postStopNotification() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            BroadcastConstants.stopBroadcastNotification,
            nil, nil, true
        )
    }
}

// MARK: - Toolbar (unchanged)
func toolBar() -> some View {
    @Environment(\.dismiss) var dismiss
    return ZStack {
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
        Text("Screen Time")
            .font(.system(size: 25, weight: .bold))
    }
}

// MARK: - Duration Section (unchanged)
func durationSection(hours: Binding<Int>, minutes: Binding<Int>, seconds: Binding<Int>) -> some View {
    return VStack(alignment: .leading) {
        Text("Duration")
            .font(.system(size: 17, weight: .semibold))
        timeSelection(hours: hours, minutes: minutes, seconds: seconds)
    }
}

// MARK: - Time Selection (unchanged)
func timeSelection(hours: Binding<Int>, minutes: Binding<Int>, seconds: Binding<Int>) -> some View {
    return VStack(alignment: .center) {
        HStack {
            Picker("Hours", selection: hours) {
                ForEach(0..<24) { hour in Text("\(hour) h").tag(hour) }
            }
            Picker("Minutes", selection: minutes) {
                ForEach(0..<60) { minute in Text("\(minute) m").tag(minute) }
            }
            Picker("Seconds", selection: seconds) {
                ForEach(0..<60) { second in Text("\(second) s").tag(second) }
            }
        }
        .pickerStyle(.wheel)

        VStack(alignment: .leading) {
            Text("Quick Select")
                .font(.system(size: 17, weight: .semibold))
            HStack {
                PrimaryButton(title: "1 hour", size: .small) { withAnimation { hours.wrappedValue = 1 } }
                Spacer()
                PrimaryButton(title: "2 hour", size: .small) { withAnimation { hours.wrappedValue = 2 } }
                Spacer()
                PrimaryButton(title: "3 hour", size: .small) { withAnimation { hours.wrappedValue = 3 } }
            }
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Broadcast Picker (local, full-frame hit area)

/// Wraps RPSystemBroadcastPickerView and stretches its internal UIButton to fill
/// the entire SwiftUI frame — so the whole "Start Session" button area is tappable.
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
