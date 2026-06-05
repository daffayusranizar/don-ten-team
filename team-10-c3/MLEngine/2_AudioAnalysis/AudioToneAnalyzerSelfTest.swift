//
//  AudioToneAnalyzerSelfTest.swift
//  team-10-c3
//

import AVFoundation
import Foundation

#if DEBUG
enum AudioToneAnalyzerSelfTest {
    struct CaseResult: Sendable {
        let name: String
        let passed: Bool
        let detail: String
    }

    static func runAll() async -> [CaseResult] {
        var results: [CaseResult] = []

        results.append(await runCase(
            name: "near_silent_pcm",
            samples: nearSilentSamples(count: 12_000),
            transcript: "",
            expectCharacterContains: "silent"
        ))

        results.append(await runCase(
            name: "energetic_sine",
            samples: sineWaveSamples(frequency: 440, amplitude: 0.35, count: 12_000),
            transcript: "",
            expectEnergyContains: "energetic"
        ))

        results.append(await runCase(
            name: "transcript_without_pcm",
            samples: [],
            transcript: "Today we are learning about plants and photosynthesis in science class.",
            expectDescriptionContains: "spoken"
        ))

        results.append(await runCase(
            name: "fast_pace_transcript",
            samples: [],
            transcript: "one two three four five six seven eight nine ten eleven twelve",
            durationSeconds: 3,
            expectDescriptionContains: "fast urgent"
        ))

        results.append(testSessionToneSilentMajority())
        results.append(testTranscriptDigestDedupes())

        return results
    }

    private static func runCase(
        name: String,
        samples: [Float],
        transcript: String,
        durationSeconds: TimeInterval = 3,
        expectCharacterContains: String? = nil,
        expectEnergyContains: String? = nil,
        expectDescriptionContains: String? = nil
    ) async -> CaseResult {
        let analyzer = ScreenRecordingAudioToneAnalyzer()
        let url: URL
        if samples.isEmpty {
            url = URL(fileURLWithPath: "/dev/null")
        } else {
            guard let written = writeWAV(samples: samples) else {
                return CaseResult(name: name, passed: false, detail: "Failed to write temp WAV")
            }
            url = written
        }

        let analysis = await analyzer.analyze(
            wavURL: url,
            transcript: transcript,
            durationSeconds: durationSeconds
        )

        if samples.isEmpty == false, url.path != "/dev/null" {
            try? FileManager.default.removeItem(at: url)
        }

        var checks: [Bool] = []
        if let expectCharacterContains {
            checks.append(analysis.character.lowercased().contains(expectCharacterContains))
        }
        if let expectEnergyContains {
            checks.append(analysis.energy.lowercased().contains(expectEnergyContains))
        }
        if let expectDescriptionContains {
            checks.append(analysis.description.lowercased().contains(expectDescriptionContains))
        }

        let passed = checks.isEmpty ? false : checks.allSatisfy { $0 }
        return CaseResult(
            name: name,
            passed: passed,
            detail: analysis.description
        )
    }

    private static func testSessionToneSilentMajority() -> CaseResult {
        let screens = [
            StoredScreenBreakdown(
                id: 0, timestampLabel: "0:00", timestampSeconds: 0,
                categoryLabel: "Entertainment", contentSummary: nil,
                creatorHandle: nil, confidence: nil,
                audioTranscript: nil,
                audioTone: AudioToneLabels.silentDescription,
                audioLabel: nil
            ),
            StoredScreenBreakdown(
                id: 1, timestampLabel: "0:03", timestampSeconds: 3,
                categoryLabel: "Entertainment", contentSummary: nil,
                creatorHandle: nil, confidence: nil,
                audioTranscript: nil,
                audioTone: AudioToneLabels.silentDescription,
                audioLabel: nil
            ),
        ]
        let summary = SessionToneSummarizer.summarize(screens: screens)
        let passed = summary.confidence == .low
            && summary.parentFacingSummary.lowercased().contains("wasn't clear enough")
        return CaseResult(name: "session_tone_silent_majority", passed: passed, detail: summary.parentFacingSummary)
    }

    private static func testTranscriptDigestDedupes() -> CaseResult {
        let digest = TranscriptDigestBuilder.buildDigest(
            perWindowTranscripts: ["hello world", "hello world", "next clip phrase"],
            fullTrackText: nil
        )
        let passed = digest == "hello world next clip phrase"
        return CaseResult(name: "transcript_digest_dedupes", passed: passed, detail: digest ?? "(nil)")
    }

    // MARK: - Sample synthesis

    private static func nearSilentSamples(count: Int) -> [Float] {
        (0 ..< count).map { _ in Float.random(in: -0.0005 ... 0.0005) }
    }

    private static func sineWaveSamples(frequency: Float, amplitude: Float, count: Int, sampleRate: Float = 16_000) -> [Float] {
        (0 ..< count).map { index in
            let t = Float(index) / sampleRate
            return amplitude * sin(2 * Float.pi * frequency * t)
        }
    }

    private static func writeWAV(samples: [Float], sampleRate: Int = 16_000) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tone-selftest-\(UUID().uuidString).wav")

        var pcm = Data()
        for sample in samples {
            let clamped = max(-1, min(1, sample))
            let int16 = Int16(clamped * Float(Int16.max))
            var le = int16.littleEndian
            pcm.append(Data(bytes: &le, count: 2))
        }

        var header = WAVHeader(sampleRate: sampleRate, channels: 1, dataSize: pcm.count)
        guard let headerData = header.data else { return nil }

        do {
            try (headerData + pcm).write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private struct WAVHeader {
        let sampleRate: Int
        let channels: Int
        let dataSize: Int

        var data: Data? {
            var d = Data()
            d.append(contentsOf: "RIFF".utf8)
            var chunkSize = UInt32(36 + dataSize).littleEndian
            d.append(Data(bytes: &chunkSize, count: 4))
            d.append(contentsOf: "WAVE".utf8)
            d.append(contentsOf: "fmt ".utf8)
            var subchunk1Size = UInt32(16).littleEndian
            d.append(Data(bytes: &subchunk1Size, count: 4))
            var audioFormat = UInt16(1).littleEndian
            d.append(Data(bytes: &audioFormat, count: 2))
            var channelCount = UInt16(channels).littleEndian
            d.append(Data(bytes: &channelCount, count: 2))
            var sampleRateLE = UInt32(sampleRate).littleEndian
            d.append(Data(bytes: &sampleRateLE, count: 4))
            let byteRate = UInt32(sampleRate * channels * 2).littleEndian
            var byteRateLE = byteRate
            d.append(Data(bytes: &byteRateLE, count: 4))
            var blockAlign = UInt16(channels * 2).littleEndian
            d.append(Data(bytes: &blockAlign, count: 2))
            var bitsPerSample = UInt16(16).littleEndian
            d.append(Data(bytes: &bitsPerSample, count: 2))
            d.append(contentsOf: "data".utf8)
            var dataSizeLE = UInt32(dataSize).littleEndian
            d.append(Data(bytes: &dataSizeLE, count: 4))
            return d
        }
    }
}
#endif
