import Accelerate
import AVFoundation
import Foundation

public struct AudioToneAnalysis: Sendable {
    public let description: String
    public let energy: String
    public let character: String
    public let pace: String?

    public init(description: String, energy: String, character: String, pace: String?) {
        self.description = description
        self.energy = energy
        self.character = character
        self.pace = pace
    }
}

public enum AudioToneLabels {
    public static let silentDescription = "silent or unreadable audio"

    public static func isSilentDescription(_ description: String) -> Bool {
        let lower = description.lowercased()
        return lower.contains("silent") || lower.contains("unreadable")
    }
}

public actor ScreenRecordingAudioToneAnalyzer {

    public init() {}

    public func analyze(
        wavURL: URL,
        transcript: String = "",
        durationSeconds: TimeInterval = 3.0
    ) -> AudioToneAnalysis {
        let sanitizedTranscript = TranscriptSanitizer.sanitize(transcript)
        let hasMeaningfulTranscript = TranscriptSanitizer.isMeaningful(sanitizedTranscript)
            && !TranscriptSanitizer.isLikelyHallucination(sanitizedTranscript)

        guard let samples = loadPCMSamples(from: wavURL), !samples.isEmpty else {
            if hasMeaningfulTranscript {
                return inferredSpokenAnalysis(transcript: sanitizedTranscript, durationSeconds: durationSeconds)
            }
            return silentAnalysis()
        }

        let rms = rootMeanSquare(samples)
        let zcr = zeroCrossingRate(samples)
        let brightness = highFrequencyEnergy(samples)

        let energy = energyLabel(rms: rms)
        let character = characterLabel(
            rms: rms,
            zcr: zcr,
            brightness: brightness,
            hasTranscript: hasMeaningfulTranscript
        )
        let pace = paceLabel(transcript: sanitizedTranscript, durationSeconds: durationSeconds)

        var parts = ["\(energy) \(character) audio"]
        if let pace {
            parts.append(pace)
        }
        if hasMeaningfulTranscript {
            parts.append("with spoken words")
        } else if character.contains("music") {
            parts.append("without clear speech")
        }

        let description = parts.joined(separator: ", ")

        if AudioToneLabels.isSilentDescription(description), hasMeaningfulTranscript {
            return inferredSpokenAnalysis(transcript: sanitizedTranscript, durationSeconds: durationSeconds)
        }

        return AudioToneAnalysis(
            description: description,
            energy: energy,
            character: character,
            pace: pace
        )
    }

    private func silentAnalysis() -> AudioToneAnalysis {
        AudioToneAnalysis(
            description: AudioToneLabels.silentDescription,
            energy: "silent",
            character: "silent",
            pace: nil
        )
    }

    private func inferredSpokenAnalysis(
        transcript: String,
        durationSeconds: TimeInterval
    ) -> AudioToneAnalysis {
        let pace = paceLabel(transcript: transcript, durationSeconds: durationSeconds)
        var parts = ["calm spoken audio", "with spoken words"]
        if let pace {
            parts.append(pace)
        }
        return AudioToneAnalysis(
            description: parts.joined(separator: ", "),
            energy: "calm",
            character: "spoken",
            pace: pace
        )
    }

    private func loadPCMSamples(from wavURL: URL) -> [Float]? {
        do {
            let file = try AVAudioFile(forReading: wavURL)
            let format = file.processingFormat
            let frameCapacity = AVAudioFrameCount(file.length)
            guard frameCapacity > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
                return nil
            }
            try file.read(into: buffer)

            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else { return nil }

            let samples: [Float]
            if let floatChannel = buffer.floatChannelData?[0] {
                samples = Array(UnsafeBufferPointer(start: floatChannel, count: frameLength))
            } else if let int16Channel = buffer.int16ChannelData?[0] {
                samples = (0 ..< frameLength).map { Float(int16Channel[$0]) / Float(Int16.max) }
            } else {
                return nil
            }

            return peakNormalize(samples)
        } catch {
            return nil
        }
    }

    private func peakNormalize(_ samples: [Float]) -> [Float] {
        guard let peak = samples.map({ abs($0) }).max(), peak > 1e-6 else { return samples }
        let scale = min(1.0 / peak, 10.0)
        return samples.map { $0 * scale }
    }

    private func rootMeanSquare(_ samples: [Float]) -> Float {
        var rms: Float = 0
        samples.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            vDSP_rmsqv(base, 1, &rms, vDSP_Length(buffer.count))
        }
        return rms
    }

    private func zeroCrossingRate(_ samples: [Float]) -> Float {
        guard samples.count > 1 else { return 0 }
        var crossings = 0
        for index in 1 ..< samples.count {
            let previous = samples[index - 1]
            let current = samples[index]
            if (previous >= 0 && current < 0) || (previous < 0 && current >= 0) {
                crossings += 1
            }
        }
        return Float(crossings) / Float(samples.count - 1)
    }

    private func highFrequencyEnergy(_ samples: [Float]) -> Float {
        guard samples.count > 1 else { return 0 }
        var total: Float = 0
        for index in 1 ..< samples.count {
            total += abs(samples[index] - samples[index - 1])
        }
        return total / Float(samples.count - 1)
    }

    private func energyLabel(rms: Float) -> String {
        switch rms {
        case ..<0.008:
            return "quiet"
        case ..<0.04:
            return "calm"
        case ..<0.12:
            return "moderate-energy"
        default:
            return "energetic loud"
        }
    }

    private func characterLabel(
        rms: Float,
        zcr: Float,
        brightness: Float,
        hasTranscript: Bool
    ) -> String {
        if rms < 0.008, !hasTranscript {
            return "silent"
        }

        let speechLike = zcr > 0.08
        let musicLike = brightness > 0.03 && zcr < 0.12

        if hasTranscript || speechLike {
            if musicLike {
                return "speech-over-music"
            }
            return "spoken"
        }

        if musicLike {
            return "music-heavy"
        }

        if brightness > 0.02 {
            return "sound-effect or mixed"
        }

        return "ambient"
    }

    private func paceLabel(transcript: String, durationSeconds: TimeInterval) -> String? {
        let words = transcript
            .split { $0.isWhitespace || $0.isNewline }
            .filter { !$0.isEmpty }
        guard !words.isEmpty, durationSeconds > 0 else { return nil }

        let wordsPerSecond = Float(words.count) / Float(durationSeconds)
        switch wordsPerSecond {
        case ..<1.2:
            return "slow deliberate delivery"
        case ..<2.4:
            return "normal conversational delivery"
        default:
            return "fast urgent delivery"
        }
    }
}
