import CoreVideo
import Foundation
import UIKit
import Vision

/// Extracts on-screen text from recording frames using Vision OCR.
public enum ScreenTextRecognizer {
    public static func recognizeText(in pixelBuffer: CVPixelBuffer) async -> String? {
        await recognizeText(in: pixelBuffer, recognitionLevel: .accurate)
    }

    public static func recognizeText(in image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let raw = extractLines(from: request.results)
                continuation.resume(returning: sanitized(raw))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    private static func recognizeText(
        in pixelBuffer: CVPixelBuffer,
        recognitionLevel: VNRequestTextRecognitionLevel
    ) async -> String? {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let raw = extractLines(from: request.results)
                continuation.resume(returning: sanitized(raw))
            }
            request.recognitionLevel = recognitionLevel
            request.usesLanguageCorrection = recognitionLevel == .accurate

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    private static func extractLines(from results: [Any]?) -> String {
        guard let observations = results as? [VNRecognizedTextObservation] else { return "" }
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")
    }

    private static func sanitized(_ raw: String) -> String? {
        let cleaned = OnScreenTextSanitizer.sanitizeForSummary(raw)
        guard OnScreenTextSanitizer.isUsefulOnScreenContent(cleaned) else { return nil }
        return cleaned
    }

    private static func mergedUnique(_ parts: [String]) -> String? {
        var seen = Set<String>()
        var merged: [String] = []

        for part in parts {
            let normalized = part.lowercased()
            guard seen.insert(normalized).inserted else { continue }
            merged.append(part)
        }

        guard !merged.isEmpty else { return nil }
        return merged.joined(separator: " · ")
    }
}
