import CoreVideo
import Foundation
import Vision

public struct VisionFrameAnalysis: Sendable {
    public let onScreenText: String
    public let sceneHints: [String]
    
    public init(onScreenText: String, sceneHints: [String]) {
        self.onScreenText = onScreenText
        self.sceneHints = sceneHints
    }
}

public actor VisionFrameContentAnalyzer {
    
    public init() {}
    
    public func analyze(pixelBuffer: CVPixelBuffer) -> VisionFrameAnalysis {
        VisionFrameAnalysis(
            onScreenText: recognizeText(in: pixelBuffer),
            sceneHints: classifyScenes(in: pixelBuffer)
        )
    }

    private func recognizeText(in pixelBuffer: CVPixelBuffer) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return ""
        }

        let lines = (request.results ?? []).compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        let raw = normalizeText(lines.joined(separator: " "))
        return OnScreenTextSanitizer.sanitizeForSummary(raw)
    }

    private func classifyScenes(in pixelBuffer: CVPixelBuffer) -> [String] {
        let request = VNClassifyImageRequest()

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        return (request.results ?? [])
            .filter { $0.confidence >= 0.15 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(3)
            .map(\.identifier)
            .map(humanizeSceneLabel)
    }

    private func normalizeText(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func humanizeSceneLabel(_ identifier: String) -> String {
        identifier
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }
}

public enum ScreenContentSummaryBuilder {
    public static func segmentSummary(
        label: String,
        onScreenText: String,
        sceneHints: [String],
        transcript: String?,
        audioTone: String?
    ) -> String? {
        var parts: [String] = []

        let category = label
            .replacingOccurrences(of: " content", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !category.isEmpty {
            parts.append(category)
        }

        let screen = OnScreenTextSanitizer.sanitizeForSummary(onScreenText)
        if OnScreenTextSanitizer.isUsefulOnScreenContent(screen) {
            parts.append("On screen: \(truncate(screen, limit: 100))")
        }

        let spoken = TranscriptSanitizer.sanitize(transcript ?? "")
        if TranscriptSanitizer.isMeaningful(spoken) {
            parts.append("Spoken: \(truncate(spoken, limit: 160))")
        } else if let audioTone {
            let trimmedTone = audioTone.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTone.isEmpty, trimmedTone != "silent or unreadable audio" {
                parts.append("Audio: \(truncate(trimmedTone, limit: 80))")
            }
        }

        if screen.isEmpty, spoken.isEmpty, !sceneHints.isEmpty {
            parts.append("Visual: \(sceneHints.prefix(2).joined(separator: ", "))")
        }

        guard parts.count > 1 || !screen.isEmpty || !spoken.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    /// Parent-readable summary when Apple Intelligence is unavailable (no raw OCR dump).
    public static func parentFacingRecordingSummary(
        timeline: [FrameClassificationSummary],
        dominantCategory: String
    ) -> String? {
        guard !timeline.isEmpty else { return nil }

        let segmentCount = timeline.count
        let estimatedMinutes = max(1, (segmentCount * 3) / 60)

        var categoryCounts: [String: Int] = [:]
        for item in timeline {
            let name = item.label
                .replacingOccurrences(of: " content", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            categoryCounts[name, default: 0] += 1
        }

        let sortedCategories = categoryCounts.sorted { $0.value > $1.value }
        let categoryPhrase: String
        if sortedCategories.count <= 1, let only = sortedCategories.first {
            categoryPhrase = only.key.lowercased()
        } else {
            let parts = sortedCategories.prefix(3).map { entry in
                let pct = Int((Double(entry.value) / Double(segmentCount)) * 100)
                return "\(entry.key) (\(pct)%)"
            }
            categoryPhrase = parts.joined(separator: ", ")
        }

        var themes: [String] = []
        for item in timeline {
            if let prompt = item.videoMatchedPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
               !prompt.isEmpty,
               !themes.contains(prompt) {
                themes.append(truncate(prompt, limit: 80))
            }
            if themes.count >= 2 { break }
        }

        if themes.isEmpty {
            let spokenSnippets = timeline.compactMap { item -> String? in
                guard let transcript = item.audioTranscript else { return nil }
                let spoken = TranscriptSanitizer.sanitize(transcript)
                guard TranscriptSanitizer.isQuotableSnippet(spoken) else { return nil }
                return truncate(spoken, limit: 90)
            }
            themes = orderedUnique(spokenSnippets).prefix(2).map { $0 }
        }

        let dominant = dominantCategory
            .replacingOccurrences(of: " content", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        var sentences: [String] = []
        let durationLabel = estimatedMinutes == 1 ? "about a minute" : "about \(estimatedMinutes) minutes"
        sentences.append(
            "During this session (\(durationLabel)), the screen was mostly \(dominant) content."
        )
        if sortedCategories.count > 1 {
            sentences.append("Time broke down as: \(categoryPhrase).")
        }
        if !themes.isEmpty {
            let themeList = themes.joined(separator: "; ")
            sentences.append("Notable themes included \(themeList).")
        }
        sentences.append("Open the screen-by-screen breakdown for more detail.")
        return sentences.joined(separator: " ")
    }

    public static func mergeSegmentSummaries(_ summaries: [String]) -> String? {
        let cleaned = summaries.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return nil }
        return cleaned.max(by: { $0.count < $1.count })
    }

    private static func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let index = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for value in values where seen.insert(value).inserted {
            ordered.append(value)
        }
        return ordered
    }
}