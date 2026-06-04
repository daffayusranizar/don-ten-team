import ReplayKit
import AVFoundation

class SampleHandler: RPBroadcastSampleHandler {

    // MARK: - Writer state

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var videoAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private let frameEncoder = BroadcastFrameEncoder()
    private var lockedSize: BroadcastEncodeSize?

    private var tempRecordingURL: URL?

    // MARK: - Session state

    private var isRecording = false
    private var isWriterConfigured = false
    private var stopRequested = false

    private var lastSavedFrameTime: TimeInterval = 0
    private let frameInterval: TimeInterval = 1.0

    // MARK: - Stop helpers

    private var stopWorkItem: DispatchWorkItem?
    private var darwinObserverToken: UnsafeMutableRawPointer?

    // MARK: - Broadcast lifecycle

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        BroadcastExtensionLog.reset()
        log("🚀 broadcastStarted")

        registerDarwinObserver()

        let appGroupID = BroadcastAppGroup.identifier
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            log("❌ App Group '\(appGroupID)' not accessible — aborting setup")
            return
        }

        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(true, forKey: BroadcastStorageKeys.broadcastActive)

        let sessionIdString = defaults?.string(forKey: BroadcastStorageKeys.activeRecordingSessionId)
        let filename: String
        if let sessionIdString,
           !sessionIdString.isEmpty,
           let sessionId = UUID(uuidString: sessionIdString) {
            filename = SessionRecordingFilename.mp4Name(sessionId: sessionId)
            log("📎 Bound broadcast to session \(sessionIdString)")
        } else {
            filename = "screen_recording_\(Int(Date().timeIntervalSince1970)).mp4"
            log("⚠️ No ActiveRecordingSessionId — fallback filename")
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let finalURL = groupURL.appendingPathComponent(filename)
        tempRecordingURL = tempURL
        defaults?.set(finalURL.path, forKey: BroadcastStorageKeys.latestRecordingPath)
        defaults?.removeObject(forKey: BroadcastStorageKeys.recordingCompletedSessionId)
        defaults?.synchronize()

        scheduleAutoStop(defaults: defaults)

        do {
            try? FileManager.default.removeItem(at: tempURL)
            assetWriter = try AVAssetWriter(outputURL: tempURL, fileType: .mp4)
            isRecording = true
            log("✅ Writer ready → \(tempURL.lastPathComponent)")
        } catch {
            log("❌ AVAssetWriter init failed: \(error)")
        }
    }

    override func broadcastPaused() {}
    override func broadcastResumed() {}

    override func broadcastFinished() {
        log("🏁 broadcastFinished")
        removeDarwinObserver()
        stopWorkItem?.cancel()
        stopWorkItem = nil

        guard isRecording else { return }
        isRecording = false

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        guard let writer = assetWriter, writer.status == .writing else {
            log("⚠️ Writer not in writing state (status \(assetWriter?.status.rawValue ?? -1))")
            if let tempURL = tempRecordingURL,
               FileManager.default.fileExists(atPath: tempURL.path) {
                log("⚠️ Attempting to salvage temp recording")
                moveRecordingToAppGroup()
            }
            markBroadcastInactive()
            return
        }

        // Keep the extension process alive until the file is fully written.
        // finishWriting dispatches its completion handler on an internal serial queue
        // (different from the ReplayKit callback thread), so the semaphore will not deadlock.
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { [weak self] in
            self?.moveRecordingToAppGroup()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 15)
        markBroadcastInactive()
        log("✅ broadcastFinished complete")
    }

    // MARK: - Sample buffer processing

    override func processSampleBuffer(
        _ sampleBuffer: CMSampleBuffer,
        with sampleBufferType: RPSampleBufferType
    ) {
        guard isRecording, let writer = assetWriter else { return }

        switch sampleBufferType {
        case .video:
            let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))

            if !isWriterConfigured {
                configureVideoInputs(from: sampleBuffer, writer: writer)
            }

            guard writer.status == .writing else { return }
            guard timestamp - lastSavedFrameTime >= frameInterval || lastSavedFrameTime == 0 else { return }
            lastSavedFrameTime = timestamp

            appendVideoFrame(from: sampleBuffer,
                             timestamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))

        case .audioApp, .audioMic:
            guard isWriterConfigured, writer.status == .writing else { return }
            if audioInput?.isReadyForMoreMediaData == true {
                audioInput?.append(sampleBuffer)
            }

        @unknown default:
            break
        }
    }

    // MARK: - Writer configuration (first frame)

    private func configureVideoInputs(from sampleBuffer: CMSampleBuffer, writer: AVAssetWriter) {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            log("❌ No format description on first video frame"); return
        }

        let dims = CMVideoFormatDescriptionGetDimensions(formatDesc)
        let size = frameEncoder.lockedEncodeSize(
            sourceWidth: Int(dims.width),
            sourceHeight: Int(dims.height)
        )
        lockedSize = size
        log("📏 Source \(dims.width)×\(dims.height) → locked encode \(size.width)×\(size.height)")

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
        ]
        let vi = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vi.expectsMediaDataInRealTime = true

        let adaptorAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: vi,
            sourcePixelBufferAttributes: adaptorAttrs
        )

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 64000,
        ]
        let ai = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        ai.expectsMediaDataInRealTime = true

        if writer.canAdd(vi) { writer.add(vi) } else { log("❌ canAdd(videoInput) false") }
        if writer.canAdd(ai) { writer.add(ai) } else { log("❌ canAdd(audioInput) false") }
        videoInput = vi
        audioInput = ai
        videoAdaptor = adaptor

        let started = writer.startWriting()
        writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        isWriterConfigured = true
        log("⚡️ startWriting: \(started), status: \(writer.status.rawValue)")
    }

    // MARK: - Frame appending

    private func appendVideoFrame(from sampleBuffer: CMSampleBuffer, timestamp: CMTime) {
        guard let adaptor = videoAdaptor,
              let size = lockedSize,
              videoInput?.isReadyForMoreMediaData == true else { return }

        guard let srcBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Log dimension changes caused by wired-display topology changes.
        let srcW = CVPixelBufferGetWidth(srcBuffer)
        let srcH = CVPixelBufferGetHeight(srcBuffer)
        if frameEncoder.sourceDimensionsChanged(sourceWidth: srcW, sourceHeight: srcH) {
            log("📐 Display size changed: \(srcW)×\(srcH) — scaling to locked \(size.width)×\(size.height)")
        }

        guard let scaled = frameEncoder.scale(
            pixelBuffer: srcBuffer,
            to: size,
            pool: adaptor.pixelBufferPool
        ) else {
            log("⚠️ Frame scaling failed — skipping frame")
            return
        }

        adaptor.append(scaled, withPresentationTime: timestamp)
    }

    // MARK: - Stop

    /// Called by Darwin observer and GCD auto-stop timer.
    /// Calls `finishBroadcastWithError` so ReplayKit stops delivering samples and
    /// then invokes `broadcastFinished`, which handles the actual file finalization.
    private func triggerStop(reason: String) {
        guard !stopRequested else { return }
        stopRequested = true
        log("🛑 triggerStop: \(reason)")
        let err = NSError(
            domain: BroadcastAppGroup.identifier + ".broadcast",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: reason]
        )
        finishBroadcastWithError(err)
    }

    // MARK: - Darwin observer

    private func registerDarwinObserver() {
        removeDarwinObserver()
        let token = Unmanaged.passRetained(self).toOpaque()
        darwinObserverToken = token
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            token,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let handler = Unmanaged<SampleHandler>.fromOpaque(observer).takeUnretainedValue()
                handler.log("📲 Darwin stopBroadcast received")
                handler.triggerStop(reason: "Session timer completed")
            },
            BroadcastNotifications.stopBroadcast.rawValue,
            nil,
            .deliverImmediately
        )
    }

    private func removeDarwinObserver() {
        guard let token = darwinObserverToken else { return }
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            token, nil, nil
        )
        Unmanaged<SampleHandler>.fromOpaque(token).release()
        darwinObserverToken = nil
    }

    // MARK: - Auto-stop timer

    private func scheduleAutoStop(defaults: UserDefaults?) {
        let targetMinutes = defaults?.integer(forKey: BroadcastStorageKeys.targetSessionDurationMinutes) ?? 0
        guard targetMinutes > 0 else { return }
        let delay = Double(targetMinutes * 60)
        log("⏱ Auto-stop in \(Int(delay))s")
        let item = DispatchWorkItem { [weak self] in
            self?.log("⏱ GCD auto-stop timer fired")
            self?.triggerStop(reason: "Session timer completed")
        }
        stopWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    // MARK: - File move + notifications

    private func moveRecordingToAppGroup() {
        guard let tempURL = tempRecordingURL else { return }
        let appGroupID = BroadcastAppGroup.identifier
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            log("❌ App Group inaccessible — cannot move recording"); return
        }
        let finalURL = groupURL.appendingPathComponent(tempURL.lastPathComponent)
        do {
            try? FileManager.default.removeItem(at: finalURL)
            try FileManager.default.moveItem(at: tempURL, to: finalURL)
            let defaults = UserDefaults(suiteName: appGroupID)
            defaults?.set(finalURL.path, forKey: BroadcastStorageKeys.latestRecordingPath)
            if let sessionIdString = defaults?.string(forKey: BroadcastStorageKeys.activeRecordingSessionId),
               !sessionIdString.isEmpty {
                defaults?.set(sessionIdString, forKey: BroadcastStorageKeys.recordingCompletedSessionId)
            }
            defaults?.synchronize()
            log("✅ Recording moved to App Group: \(finalURL.lastPathComponent)")
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                BroadcastNotifications.recordingReady,
                nil, nil, true
            )
        } catch {
            log("❌ Failed to move recording: \(error.localizedDescription)")
        }
    }

    private func markBroadcastInactive() {
        let appGroupID = BroadcastAppGroup.identifier
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(false, forKey: BroadcastStorageKeys.broadcastActive)
        defaults?.synchronize()
    }

    private func log(_ message: String) {
        BroadcastExtensionLog.append(message)
    }
}
