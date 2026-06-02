import ReplayKit
import AVFoundation

class SampleHandler: RPBroadcastSampleHandler {
    
    private var appGroupID: String {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
            ?? "group.abui.don-ten-team.shared"
    }
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?

    private var lastSavedFrameTime: TimeInterval = 0
    private let frameInterval: TimeInterval = 1.0

    private var recordingURL: URL?
    private var isRecording = false
    private var stopWorkItem: DispatchWorkItem?

    private func log(_ message: String) {
        print(message)
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return }
        let logURL = groupURL.appendingPathComponent("extension_debug.log")
        let entry = "[\(Date().description)] \(message)\n"
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            if let data = entry.data(using: .utf8) { handle.write(data) }
            handle.closeFile()
        } else {
            try? entry.write(to: logURL, atomically: true, encoding: .utf8)
        }
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        log("🚀 Extension Started!")
        
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passRetained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let handler = Unmanaged<SampleHandler>.fromOpaque(observer).takeUnretainedValue()
                handler.log("⏱ Darwin stop signal received.")
                handler.finalizeAndSave()
                let err = NSError(domain: "com.team10.c3.timeout", code: 0,
                                  userInfo: [NSLocalizedDescriptionKey: "Session timer completed"])
                handler.finishBroadcastWithError(err)
            },
            "com.team10.c3.stopBroadcast" as CFString,
            nil,
            .deliverImmediately
        )

        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            log("❌ App Group '\(appGroupID)' not accessible.")
            return
        }

        // Wipe old log on start
        let logURL = groupURL.appendingPathComponent("extension_debug.log")
        try? FileManager.default.removeItem(at: logURL)
        log("🚀 Fresh Session Started!")

        let filename = "screen_recording_\(Int(Date().timeIntervalSince1970)).mp4"
        
        // CRITICAL FIX: AVAssetWriter (via mediaserverd) cannot write directly to App Groups on some devices
        // because of sandbox restrictions. We MUST write to the extension's temporary directory first!
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        recordingURL = tempURL
        
        // We will move it to the App Group later. Let's pre-calculate the final App Group URL.
        let finalAppGroupURL = groupURL.appendingPathComponent(filename)

        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.set(finalAppGroupURL.path, forKey: "LatestRecordingPath")

            let targetMinutes = defaults.integer(forKey: "TargetSessionDurationMinutes")
            if targetMinutes > 0 {
                let delay = Double(targetMinutes * 60)
                log("⏱ Auto-stopping in \(delay)s")
                let workItem = DispatchWorkItem { [weak self] in
                    self?.log("⏱ GCD timer fired.")
                    self?.finalizeAndSave()
                    let err = NSError(domain: "com.team10.c3.timeout", code: 0,
                                      userInfo: [NSLocalizedDescriptionKey: "Session timer completed"])
                    self?.finishBroadcastWithError(err)
                }
                stopWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            }
            defaults.synchronize()
        }

        do {
            // Delete any existing temp file
            try? FileManager.default.removeItem(at: tempURL)
            assetWriter = try AVAssetWriter(outputURL: tempURL, fileType: .mp4)
            isRecording = true
            log("✅ Recording setup complete. Writing to TEMP dir first... → \(tempURL.lastPathComponent)")
        } catch {
            log("❌ AVAssetWriter init failed: \(error)")
        }
    }

    override func broadcastPaused() {}
    override func broadcastResumed() {}

    override func broadcastFinished() {
        finalizeAndSave()
    }

    private func finalizeAndSave() {
        guard isRecording else { return }
        isRecording = false
        stopWorkItem?.cancel()
        stopWorkItem = nil

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        guard let writer = assetWriter else { return }

        guard writer.status == .writing else {
            log("⚠️ Writer not in writing state (Status: \(writer.status.rawValue)). Error: \(writer.error?.localizedDescription ?? "None")")
            return
        }

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { [weak self] in
            defer { semaphore.signal() }
            guard let self, let tempURL = self.recordingURL else { return }

            let existsInTemp = FileManager.default.fileExists(atPath: tempURL.path)
            self.log("✅ finishWriting done. File exists in TEMP: \(existsInTemp)")

            guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.appGroupID) else {
                self.log("❌ Could not access App Group to move file.")
                return
            }

            let finalURL = groupURL.appendingPathComponent(tempURL.lastPathComponent)
            do {
                try? FileManager.default.removeItem(at: finalURL)
                try FileManager.default.moveItem(at: tempURL, to: finalURL)
                self.log("✅ Successfully moved MP4 to App Group: \(finalURL.path)")
                
                if let defaults = UserDefaults(suiteName: self.appGroupID) {
                    defaults.set(finalURL.path, forKey: "LatestRecordingPath")
                    defaults.synchronize()
                }

                CFNotificationCenterPostNotification(
                    CFNotificationCenterGetDarwinNotifyCenter(),
                    CFNotificationName("com.team10.c3.recordingReady" as CFString),
                    nil, nil, true
                )
            } catch {
                self.log("❌ Failed to move MP4 to App Group: \(error.localizedDescription)")
            }
        }
        _ = semaphore.wait(timeout: .now() + 10.0)
        log("✅ finalizeAndSave completed.")
    }

    private var isWriterConfigured = false
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard isRecording, let writer = assetWriter else { return }

        switch sampleBufferType {
        case .video:
            let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            
            if !isWriterConfigured {
                log("⚡️ First Video Frame Received. Configuring Inputs...")
                guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { 
                    log("❌ ERROR: formatDescription is nil!")
                    return 
                }
                let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
                log("📏 Video Dimensions: \(dimensions.width)x\(dimensions.height)")
                
                // Ensure dimensions are even numbers (H264 hardware encoders can fail with odd dimensions like 1179 on iPhone 14 Pro)
                var width = Int(dimensions.width)
                var height = Int(dimensions.height)
                if width % 2 != 0 { width -= 1 }
                if height % 2 != 0 { height -= 1 }
                
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: width,
                    AVVideoHeightKey: height
                ]
                let vi = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                vi.expectsMediaDataInRealTime = true
                if writer.canAdd(vi) { writer.add(vi); log("✅ videoInput added") } else { log("❌ Failed to add videoInput") }
                videoInput = vi
                
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: 1,
                    AVSampleRateKey: 44100,
                    AVEncoderBitRateKey: 64000
                ]
                let ai = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                ai.expectsMediaDataInRealTime = true
                if writer.canAdd(ai) { writer.add(ai); log("✅ audioInput added") } else { log("❌ Failed to add audioInput") }
                audioInput = ai
                
                let startResult = writer.startWriting()
                log("⚡️ startWriting returned: \(startResult)")
                
                writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                isWriterConfigured = true
                log("✅ Session fully started at timestamp: \(timestamp). Status: \(writer.status.rawValue). Error: \(writer.error?.localizedDescription ?? "None")")
            }
            
            guard writer.status == .writing else { return }
            guard timestamp - lastSavedFrameTime >= frameInterval || lastSavedFrameTime == 0 else { return }
            lastSavedFrameTime = timestamp

            if videoInput?.isReadyForMoreMediaData == true {
                videoInput?.append(sampleBuffer)
            }

        case .audioApp, .audioMic:
            guard isWriterConfigured, writer.status == .writing else { return }
            
            if audioInput?.isReadyForMoreMediaData == true {
                audioInput?.append(sampleBuffer)
            }
            
        @unknown default:
            break
        }
    }
}
