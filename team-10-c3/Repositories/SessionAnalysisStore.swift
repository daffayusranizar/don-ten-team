//
//  SessionAnalysisStore.swift
//  team-10-c3
//

import Foundation
import SwiftData

struct SessionAnalysisCacheEntry {
    let result: PipelineResult?
    let errorMessage: String?
}

@MainActor
final class SessionAnalysisStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func load(sessionId: UUID) -> SessionAnalysisCacheEntry? {
        var descriptor = FetchDescriptor<SessionAnalysisRecord>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )
        descriptor.fetchLimit = 1
        guard let record = try? modelContext.fetch(descriptor).first else { return nil }

        switch record.status {
        case .completed:
            guard let payloadJSON = record.payloadJSON,
                  let data = payloadJSON.data(using: .utf8),
                  let stored = try? JSONDecoder().decode(StoredPipelineResult.self, from: data) else {
                return nil
            }
            return SessionAnalysisCacheEntry(
                result: PipelineResult(stored: stored),
                errorMessage: nil
            )
        case .failed:
            return SessionAnalysisCacheEntry(
                result: nil,
                errorMessage: record.errorMessage ?? "Analysis failed."
            )
        }
    }

    func save(
        sessionId: UUID,
        childId: UUID,
        result: PipelineResult?,
        errorMessage: String?
    ) throws {
        if let existing = try fetchRecord(sessionId: sessionId) {
            modelContext.delete(existing)
        }

        let record: SessionAnalysisRecord
        if let result {
            let payload = StoredPipelineResult(from: result)
            let data = try JSONEncoder().encode(payload)
            record = SessionAnalysisRecord(
                sessionId: sessionId,
                childId: childId,
                status: .completed,
                payloadJSON: String(data: data, encoding: .utf8)
            )
        } else {
            record = SessionAnalysisRecord(
                sessionId: sessionId,
                childId: childId,
                status: .failed,
                errorMessage: errorMessage
            )
        }
        modelContext.insert(record)
        try modelContext.save()
    }

    func loadResults(sessionIds: [UUID]) -> [UUID: PipelineResult] {
        guard !sessionIds.isEmpty else { return [:] }

        let idSet = Set(sessionIds)
        let descriptor = FetchDescriptor<SessionAnalysisRecord>()
        guard let records = try? modelContext.fetch(descriptor) else { return [:] }

        var results: [UUID: PipelineResult] = [:]
        for record in records where idSet.contains(record.sessionId) {
            guard record.status == .completed,
                  let payloadJSON = record.payloadJSON,
                  let data = payloadJSON.data(using: .utf8),
                  let stored = try? JSONDecoder().decode(StoredPipelineResult.self, from: data) else {
                continue
            }
            results[record.sessionId] = PipelineResult(stored: stored)
        }
        return results
    }

    private func fetchRecord(sessionId: UUID) throws -> SessionAnalysisRecord? {
        var descriptor = FetchDescriptor<SessionAnalysisRecord>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
