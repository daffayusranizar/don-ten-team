import Foundation
import NaturalLanguage

public struct SentimentAnalysisResult: Sendable {
    public let score: Double
    public let isHighlyNegative: Bool
    
    public init(score: Double, isHighlyNegative: Bool) {
        self.score = score
        self.isHighlyNegative = isHighlyNegative
    }
}

public actor ScreenRecordingSentimentAnalyzer {
    
    public init() {}
    
    /// Analyzes the sentiment of a transcript and returns a score between -1.0 (most negative) and 1.0 (most positive).
    public func analyze(transcript: String) -> SentimentAnalysisResult {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SentimentAnalysisResult(score: 0.0, isHighlyNegative: false)
        }
        
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = trimmed
        
        let (sentiment, _) = tagger.tag(at: trimmed.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        let score = Double(sentiment?.rawValue ?? "0.0") ?? 0.0
        
        // A score below -0.6 is considered highly negative (e.g., cyberbullying, profanity, extreme anger)
        let isHighlyNegative = score <= -0.6
        
        return SentimentAnalysisResult(score: score, isHighlyNegative: isHighlyNegative)
    }
}
