import ReplayKit
import AVFoundation

class SampleHandler: RPBroadcastSampleHandler {
    
    // Must match BroadcastConstants.appGroupID and all *.entitlements files.
    private let appGroupIdentifier = "group.abui.don-ten-team.shared"
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    
    private var lastSavedFrameTime: TimeInterval = 0
    private let frameInterval: TimeInterval = 1.0 // Exactly 1 FPS
    private var recordingURL: URL?
    
    private var isRecording = false

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // User has requested to start the broadcast. Setup the recorder.
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("ERROR: App Group not configured properly.")
            return
        }
        
        let filename = "screen_recording_\(Int(Date().timeIntervalSince1970)).mp4"
        recordingURL = groupURL.appendingPathComponent(filename)
        
        do {
            assetWriter = try AVAssetWriter(outputURL: recordingURL!, fileType: .mp4)
            isRecording = true
        } catch {
            print("Failed to create AVAssetWriter: \(error)")
        }
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast.
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast.
    }
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast.
        isRecording = false
        
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        
        assetWriter?.finishWriting { [weak self] in
            guard let url = self?.recordingURL else { return }
            
            // Save the URL to UserDefaults so the Main App knows where the video is
            if let defaults = UserDefaults(suiteName: self?.appGroupIdentifier) {
                defaults.set(url.path, forKey: "LatestRecordingPath")
            }
        }
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard isRecording, let writer = assetWriter else { return }
        
        switch sampleBufferType {
        case .video:
            let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            
            // 1 FPS Throttling Magic
            // Only process the frame if 1.0 seconds have passed since the last one.
            if timestamp - lastSavedFrameTime >= frameInterval || lastSavedFrameTime == 0 {
                lastSavedFrameTime = timestamp
                
                // Initialize video input dynamically based on the first frame's format
                if videoInput == nil {
                    guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
                    let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
                    
                    let settings: [String: Any] = [
                        AVVideoCodecKey: AVVideoCodecType.hevc,
                        AVVideoWidthKey: dimensions.width,
                        AVVideoHeightKey: dimensions.height
                    ]
                    
                    videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
                    videoInput?.expectsMediaDataInRealTime = true
                    
                    if writer.canAdd(videoInput!) {
                        writer.add(videoInput!)
                    }
                    
                    writer.startWriting()
                    writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                }
                
                if videoInput?.isReadyForMoreMediaData == true {
                    videoInput?.append(sampleBuffer)
                }
            }
            
        case .audioApp, .audioMic:
            // We want ALL audio frames to ensure the Whisper transcript is flawless
            if audioInput == nil {
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: 1,
                    AVSampleRateKey: 44100,
                    AVEncoderBitRateKey: 64000
                ]
                audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
                audioInput?.expectsMediaDataInRealTime = true
                if writer.canAdd(audioInput!) {
                    writer.add(audioInput!)
                }
            }
            
            // Ensure writer session has started before appending audio
            if writer.status == .writing && audioInput?.isReadyForMoreMediaData == true {
                audioInput?.append(sampleBuffer)
            }
            
        @unknown default:
            break
        }
    }
}
