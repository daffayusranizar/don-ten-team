import Foundation
import UIKit

public struct FrameClassificationSummary: Identifiable, Sendable {
    public let id: Int
    public let timestamp: TimeInterval
    public let label: String
    public let matchedPrompt: String?
    public let videoMatchedPrompt: String?
    public let audioMatchedPrompt: String?
    public let probability: Float
    // Note: UIImage is NOT Sendable by default in Swift 6. 
    // In a pure backend pipeline, you might want to return the CVPixelBuffer or just a file path URL.
    // For now, we mark this struct as @unchecked Sendable if UIImage causes warnings, 
    // but assuming UIKit is imported, we will leave it as is for the migration.
    public let thumbnail: UIImage?
    public let bottomCropThumbnail: UIImage?
    public let audioTranscript: String?
    public let audioTone: String?
    public let audioLabel: String?
    public let contentSummary: String?
    public let creatorHandle: String?
}

public actor ScreenRecordingAggregator {
    private let videoWeight: Float = 0.35
    private let audioWeight: Float = 0.65

    public init() {}

    public func aggregate(
        frameResults: [[ClassificationMatch]],
        labels: [String],
        temperature: Float
    ) -> [ClassificationMatch] {
        guard !frameResults.isEmpty else { return [] }

        var summedScores = Dictionary(uniqueKeysWithValues: labels.map { ($0, Float.zero) })
        for results in frameResults {
            for match in results {
                summedScores[match.label, default: 0] += match.score
            }
        }

        let frameCount = Float(frameResults.count)
        let averagedSimilarities = labels.map { label in
            (summedScores[label] ?? 0) / frameCount
        }

        let probabilities = CLIPScoring.softmaxProbabilities(
            similarities: averagedSimilarities,
            temperature: temperature
        )

        return labels.enumerated().map { index, label in
            ClassificationMatch(
                id: label,
                label: label,
                score: averagedSimilarities[index],
                probability: probabilities[index],
                matchedPrompt: nil
            )
        }
        .sorted { $0.probability > $1.probability }
    }

    public func mergeVideoAndAudio(
        videoMatches: [ClassificationMatch],
        audioMatches: [ClassificationMatch]?,
        labels: [String],
        temperature: Float,
        transcript: String? = nil,
        audioTone: String? = nil
    ) -> [ClassificationMatch] {
        guard let audioMatches, !audioMatches.isEmpty else {
            return videoMatches
        }

        let weights = fusionWeights(transcript: transcript, audioTone: audioTone)

        let videoScores = Dictionary(uniqueKeysWithValues: videoMatches.map { ($0.label, $0.score) })
        let audioScores = Dictionary(uniqueKeysWithValues: audioMatches.map { ($0.label, $0.score) })

        let blendedSimilarities = labels.map { label in
            let videoScore = videoScores[label] ?? 0
            let audioScore = audioScores[label] ?? 0
            return weights.video * videoScore + weights.audio * audioScore
        }

        let probabilities = CLIPScoring.softmaxProbabilities(
            similarities: blendedSimilarities,
            temperature: temperature
        )

        let videoTop = videoMatches.first?.label
        let audioTop = audioMatches.first?.label

        return labels.enumerated().map { index, label in
            let videoMatch = videoMatches.first { $0.label == label }
            let audioMatch = audioMatches.first { $0.label == label }
            let preferVideoPrompt = videoTop == "Entertainment content"
                && audioTop == "Educational content"
                && !MobileCLIPClassifier.isInstructionalTranscript(transcript ?? "")
            let matchedPrompt = preferVideoPrompt
                ? videoMatch?.matchedPrompt
                : (audioMatch?.matchedPrompt ?? videoMatch?.matchedPrompt)
            return ClassificationMatch(
                id: label,
                label: label,
                score: blendedSimilarities[index],
                probability: probabilities[index],
                matchedPrompt: matchedPrompt
            )
        }
        .sorted { $0.probability > $1.probability }
    }

    private func fusionWeights(transcript: String?, audioTone: String?) -> (video: Float, audio: Float) {
        let trimmed = transcript?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if MobileCLIPClassifier.isInstructionalTranscript(trimmed) {
            return (0.25, 0.75)
        }
        if MobileCLIPClassifier.toneSuggestsMusic(audioTone ?? "") || trimmed.split(whereSeparator: \.isWhitespace).count < 8 {
            return (0.62, 0.38)
        }
        return (videoWeight, audioWeight)
    }

    public func timeline(
        frames: [(
            timestamp: TimeInterval,
            matches: [ClassificationMatch],
            thumbnail: UIImage?,
            bottomCropThumbnail: UIImage?,
            audioTranscript: String?,
            audioTone: String?,
            audioLabel: String?,
            videoMatchedPrompt: String?,
            audioMatchedPrompt: String?,
            contentSummary: String?,
            creatorHandle: String?,
            isDuplicate: Bool
        )],
        fps: Float,
        intervalSeconds: Int = 3
    ) -> [FrameClassificationSummary] {
        guard !frames.isEmpty else { return [] }

        let perFrameSummaries = frames.enumerated().compactMap { index, frame -> FrameClassificationSummary? in
            guard let top = frame.matches.first else { return nil }
            return FrameClassificationSummary(
                id: index,
                timestamp: frame.timestamp,
                label: top.label,
                matchedPrompt: top.matchedPrompt,
                videoMatchedPrompt: frame.videoMatchedPrompt,
                audioMatchedPrompt: frame.audioMatchedPrompt,
                probability: top.probability,
                thumbnail: frame.thumbnail,
                bottomCropThumbnail: frame.bottomCropThumbnail,
                audioTranscript: frame.audioTranscript,
                audioTone: frame.audioTone,
                audioLabel: frame.audioLabel,
                contentSummary: frame.contentSummary,
                creatorHandle: frame.creatorHandle
            )
        }

        let interval = max(1, intervalSeconds)
        if perFrameSummaries.count <= interval * 2 {
            return perFrameSummaries
        }

        let grouped = Dictionary(grouping: perFrameSummaries) { summary in
            Int(summary.timestamp) / interval * interval
        }

        return grouped.keys.sorted().compactMap { bucketStart in
            guard let bucket = grouped[bucketStart], !bucket.isEmpty else { return nil }
            let labelCounts = Dictionary(grouping: bucket, by: \.label).mapValues(\.count)
            guard let winningLabel = labelCounts.max(by: { $0.value < $1.value })?.key else { return nil }
            let matching = bucket.filter { $0.label == winningLabel }
            let averageProbability = matching.map(\.probability).reduce(0, +) / Float(matching.count)
            
            // Apply confidence threshold: If we aren't highly confident, label it as a transition.
            let finalLabel = averageProbability >= 0.55 ? winningLabel : "Unknown or Transitioning"
            
            return FrameClassificationSummary(
                id: bucketStart,
                timestamp: TimeInterval(bucketStart),
                label: finalLabel,
                matchedPrompt: matching.first?.matchedPrompt,
                videoMatchedPrompt: matching.first?.videoMatchedPrompt ?? bucket.first?.videoMatchedPrompt,
                audioMatchedPrompt: matching.first?.audioMatchedPrompt ?? bucket.first?.audioMatchedPrompt,
                probability: averageProbability,
                thumbnail: matching.first?.thumbnail ?? bucket.first?.thumbnail,
                bottomCropThumbnail: matching.first?.bottomCropThumbnail ?? bucket.first?.bottomCropThumbnail,
                audioTranscript: matching.first?.audioTranscript ?? bucket.first?.audioTranscript,
                audioTone: matching.first?.audioTone ?? bucket.first?.audioTone,
                audioLabel: matching.first?.audioLabel ?? bucket.first?.audioLabel,
                contentSummary: ScreenContentSummaryBuilder.mergeSegmentSummaries(
                    bucket.compactMap(\.contentSummary)
                ),
                creatorHandle: preferredCreatorHandle(in: bucket)
            )
        }
    }

    private func preferredCreatorHandle(in bucket: [FrameClassificationSummary]) -> String? {
        let handles = bucket.compactMap(\.creatorHandle)
        guard !handles.isEmpty else { return nil }

        let counts = Dictionary(handles.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max { $0.value < $1.value }?.key
    }
}