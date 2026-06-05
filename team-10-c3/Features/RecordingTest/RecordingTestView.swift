import SwiftUI
import ReplayKit
import Combine

// MARK: - Session Flow State
enum SessionStep {
    case setup       // Pick child + duration
    case recording   // Countdown timer active
    case processing  // AI pipeline running
    case results     // Show results
}

struct RecordingTestView: View {

    @Environment(\.profileViewModel) private var profileViewModel
    @StateObject private var recordingManager = RecordingManager.shared

    // Session State
    @State private var step: SessionStep = .setup
    @State private var selectedChild: Child?
    @State private var sessionMinutes: Int = 1

    // Countdown
    @State private var timeRemaining: TimeInterval = 0
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Pipeline Result
    @State private var result: PipelineResult? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .setup:       setupView
                case .recording:   recordingView
                case .processing:  processingView
                case .results:     resultsView
                }
            }
            .navigationTitle("Session Test")
            .navigationBarTitleDisplayMode(.inline)
        }
        // Detect when iOS screen capture starts/stops
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            handleCaptureChange()
        }
        .onReceive(NotificationCenter.default.publisher(for: RecordingReadyBridge.notification)) { _ in
            guard step == .processing else { return }
            Task { await runPipeline() }
        }
        .onAppear {
            RecordingReadyBridge.startListening()
            profileViewModel.loadChildren()
            if selectedChild == nil {
                selectedChild = profileViewModel.selectedChild ?? profileViewModel.children.first
            }
        }
    }

    // MARK: - Step 1: Setup
    private var setupView: some View {
        Form {
            Section("Child") {
                if profileViewModel.children.isEmpty {
                    Text("Add a child profile in Settings before running a test session.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Select Child", selection: $selectedChild) {
                        ForEach(profileViewModel.children) { child in
                            Text("\(child.name) (age \(child.currentAge))").tag(Optional(child))
                        }
                    }
                }
            }

            Section("Duration") {
                Stepper("\(sessionMinutes) minute\(sessionMinutes == 1 ? "" : "s")", value: $sessionMinutes, in: 1...120)
            }

            Section {
                VStack(spacing: 12) {
                    Text("Tap the button below, then choose **ScreenRecorderExtension** from the list to start recording.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    // The system broadcast picker — the only way to start a broadcast on iOS
                    BroadcastPickerView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            } header: {
                Text("Start Recording")
            }
        }
        .onAppear {
            recordingManager.setSessionDuration(minutes: sessionMinutes)
        }
        .onChange(of: sessionMinutes) { _, newValue in
            recordingManager.setSessionDuration(minutes: newValue)
        }
    }

    // MARK: - Step 2: Recording (Countdown)
    private var recordingView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("Recording in progress")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if let child = selectedChild {
                    Text(child.name)
                        .font(.title2.bold())
                }
            }

            // Big red countdown
            Text(timeString(from: timeRemaining))
                .font(.system(size: 72, weight: .bold, design: .monospaced))
                .foregroundStyle(.red)
                .padding(24)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                .onReceive(ticker) { _ in
                    if timeRemaining > 1 {
                        timeRemaining -= 1
                    } else if timeRemaining == 1 {
                        timeRemaining = 0
                        // Signal the extension to stop via Darwin notification
                        recordingManager.postStopBroadcast()
                    }
                }

            Text("Recording will stop automatically when the timer reaches 00:00")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    // MARK: - Step 3: Processing
    private var processingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Analyzing with AI…")
                .font(.headline)
            Text("This may take a moment")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Step 4: Results
    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundStyle(.red)
                        .padding()
                }

                if let result {
                    ResultCard(icon: "📊", title: "Dominant Category", value: result.category)
                    ResultCard(icon: "✍️", title: "AI Summary", value: result.summary)
                    ResultCard(icon: "💡", title: "Conversation Starter", value: result.conversationStarter)
                    ResultCard(icon: "🌿", title: "Offline Activity", value: result.offlineActivity)
                }

                Button("Start New Session") {
                    result = nil
                    errorMessage = nil
                    step = .setup
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
            .padding()
        }
    }

    // MARK: - Capture Detection
    private func handleCaptureChange() {
        if UIScreen.main.isCaptured {
            guard step == .setup else { return }
            timeRemaining = TimeInterval(sessionMinutes * 60)
            step = .recording
        } else {
            guard step == .recording else { return }
            step = .processing
            // Pipeline will be triggered by the recordingReady Darwin notification
            // once the extension has fully finished writing the file.
            // Fallback: if extension doesn't signal within 10s, try anyway.
            Task {
                try? await Task.sleep(for: .seconds(10))
                if step == .processing {
                    await runPipeline()
                }
            }
        }
    }

    // MARK: - Pipeline
    @MainActor
    private func runPipeline() async {
        guard let videoURL = findRecordingFile() else {
            let baseMessage = "No recording file found in App Group '\(recordingManager.appGroupIdentifier)'. The extension may not have saved the file properly.\n"
            
            // Try to read the extension_debug.log to see EXACTLY why AVAssetWriter failed
            if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: recordingManager.appGroupIdentifier) {
                let logURL = groupURL.appendingPathComponent("extension_debug.log")
                if let logData = try? String(contentsOf: logURL) {
                    print("\n========== EXTENSION DEBUG LOG ==========\n\(logData)\n=========================================\n")
                    errorMessage = baseMessage + "\nExtension Log:\n\(logData)"
                } else {
                    errorMessage = baseMessage + "\n(No extension debug log found)"
                }
            } else {
                errorMessage = baseMessage
            }
            
            step = .results
            return
        }

        do {
            let orchestrator = PipelineOrchestrator()
            let output = try await orchestrator.processSession(videoURL: videoURL)
            result = PipelineResult(from: output)
        } catch {
            errorMessage = error.localizedDescription
        }
        step = .results
    }
    
    private func findRecordingFile() -> URL? {
        recordingManager.findLatestRecordingURL()
    }

    private func timeString(from interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Broadcast Picker Wrapper
struct BroadcastPickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        picker.preferredExtension = BroadcastConstants.extensionBundleID
        picker.showsMicrophoneButton = false
        return picker
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

#Preview {
    RecordingTestView()
        .environment(\.profileViewModel, ProfileViewModel(childRepository: InMemoryChildRepository()))
}
