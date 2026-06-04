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
        guard TranscriptSanitizer.isMeaningful(trimmed) else {
            return SentimentAnalysisResult(score: 0.0, isHighlyNegative: false)
        }
        
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = trimmed
        
        // Get the overall paragraph score
        let (overallSentiment, _) = tagger.tag(at: trimmed.startIndex, unit: .paragraph, scheme: .sentimentScore)
        let overallScore = Double(overallSentiment?.rawValue ?? "0.0") ?? 0.0
        
        // Find the single most negative sentence to provide context
        var mostNegativeScore = 1.0
        var mostNegativeSentence: String? = nil
        
        tagger.enumerateTags(in: trimmed.startIndex..<trimmed.endIndex, unit: .sentence, scheme: .sentimentScore, options: []) { tag, tokenRange in
            if let tag = tag, let score = Double(tag.rawValue) {
                let sentence = TranscriptSanitizer.sanitize(String(trimmed[tokenRange]))
                guard TranscriptSanitizer.isQuotableSnippet(sentence) else { return true }
                if score < mostNegativeScore {
                    mostNegativeScore = score
                    mostNegativeSentence = sentence
                }
            }
            return true
        }
        
        // A score below -0.6 overall, or a single sentence below -0.8, is flagged
        let isHighlyNegative = overallScore <= -0.6 || mostNegativeScore <= -0.8
        
        return SentimentAnalysisResult(
            score: overallScore, 
            isHighlyNegative: isHighlyNegative,
            mostNegativeSnippet: isHighlyNegative ? mostNegativeSentence : nil
        )
    }
}
