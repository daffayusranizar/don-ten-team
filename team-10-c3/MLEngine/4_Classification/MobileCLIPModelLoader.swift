import Foundation

/// Preloads and caches MobileCLIP so splash-screen warm-up is reused by the analysis pipeline.
public enum MobileCLIPModelLoader {
    private static let cache = Cache()

    public static func preload() async throws {
        try await cache.preload()
    }

    public static func shared() async throws -> MobileCLIPClassifier {
        try await cache.shared()
    }
}

private actor Cache {
    private var classifier: MobileCLIPClassifier?

    func preload() async throws {
        guard classifier == nil else { return }
        classifier = try await MobileCLIPClassifier()
    }

    func shared() async throws -> MobileCLIPClassifier {
        if let classifier {
            return classifier
        }
        let loaded = try await MobileCLIPClassifier()
        classifier = loaded
        return loaded
    }
}
