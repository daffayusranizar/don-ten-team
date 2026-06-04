import Foundation
import NaturalLanguage

public struct SentimentAnalysisResult: Sendable {
    public let score: Double
    public let isHighlyNegative: Bool
    public let mostNegativeSnippet: String?

    public init(score: Double, isHighlyNegative: Bool, mostNegativeSnippet: String? = nil) {
        self.score = score
        self.isHighlyNegative = isHighlyNegative
        self.mostNegativeSnippet = mostNegativeSnippet
    }
}

public actor ScreenRecordingSentimentAnalyzer {

    public init() {}

    /// Analyzes the sentiment of a transcript and returns a score between -1.0 (most negative) and 1.0 (most positive).
    public func analyze(transcript: String) -> SentimentAnalysisResult {
        let trimmed = TranscriptSanitizer.sanitize(transcript)
        guard TranscriptSanitizer.isSubstantialForSentiment(trimmed) else {
            return SentimentAnalysisResult(score: 0.0, isHighlyNegative: false)
        }

        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = trimmed

        let (overallSentiment, _) = tagger.tag(at: trimmed.startIndex, unit: .paragraph, scheme: .sentimentScore)
        let overallScore = Double(overallSentiment?.rawValue ?? "0.0") ?? 0.0

        var negativeSentenceCount = 0
        var mostNegativeScore = 1.0
        var mostNegativeSentence: String?

        tagger.enumerateTags(in: trimmed.startIndex..<trimmed.endIndex, unit: .sentence, scheme: .sentimentScore, options: []) { tag, tokenRange in
            if let tag = tag, let score = Double(tag.rawValue) {
                let sentence = TranscriptSanitizer.sanitize(String(trimmed[tokenRange]))
                guard TranscriptSanitizer.isQuotableSnippet(sentence) else { return true }
                if score <= -0.85 {
                    negativeSentenceCount += 1
                }
                if score < mostNegativeScore {
                    mostNegativeScore = score
                    mostNegativeSentence = sentence
                }
            }
            return true
        }

        let hasQuotableNegative = mostNegativeSentence != nil
        let isHighlyNegative =
            (overallScore <= -0.65 && hasQuotableNegative)
            || (negativeSentenceCount >= 2 && mostNegativeScore <= -0.9)

        return SentimentAnalysisResult(
            score: overallScore,
            isHighlyNegative: isHighlyNegative,
            mostNegativeSnippet: isHighlyNegative ? mostNegativeSentence : nil
        )
    }
}
