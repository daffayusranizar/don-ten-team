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

struct SessionAnalysisHistoryItem: Identifiable {
    let sessionId: UUID
    let childId: UUID
    let analyzedAt: Date
    let summaryPreview: String?
    let dominantCategory: String?
    let screenCount: Int
    let errorMessage: String?

    var id: UUID { sessionId }
}

struct SavedSuggestionTry: Equatable, Sendable {
    let suggestion: String
    let tried: Bool
    let followUpSelection: String?
    let note: String?
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
                payloadJSON: String(data: data, encoding: .utf8),
                summaryPreview: result.summary,
                dominantCategory: result.dominantCategoryDisplay,
                screenCount: result.screens.count
            )
        } else {
            record = SessionAnalysisRecord(
                sessionId: sessionId,
                childId: childId,
                status: .failed,
                errorMessage: errorMessage,
                screenCount: 0
            )
        }
        modelContext.insert(record)
        try modelContext.save()
    }

    func loadResults(sessionIds: [UUID]) -> [UUID: PipelineResult] {
        guard !sessionIds.isEmpty else { return [:] }
        let idSet = Set(sessionIds)
        let ids = Array(idSet)
        let descriptor = FetchDescriptor<SessionAnalysisRecord>(
            predicate: #Predicate { ids.contains($0.sessionId) }
        )
        guard let records = try? modelContext.fetch(descriptor) else { return [:] }

        var results: [UUID: PipelineResult] = [:]
        for record in records {
            guard record.status == .completed,
                  let payloadJSON = record.payloadJSON,
                  let data = payloadJSON.data(using: .utf8),
                  let stored = try? JSONDecoder().decode(StoredPipelineResult.self, from: data) else {
                continue
            }
            results[record.sessionId] = PipelineResult(stored: stored)
        }
        print("⏱️ SessionAnalysisStore.loadResults " +
              "requested=\(idSet.count) fetched=\(records.count) decoded=\(results.count)")
        return results
    }

    func availableMonths(for childId: UUID) -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let months = fetchRecords(for: childId).map { formatter.string(from: $0.analyzedAt) }
        return Array(Set(months)).sorted(by: >)
    }

    func fetchHistory(for childId: UUID, month: String?) -> [SessionAnalysisHistoryItem] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        return fetchRecords(for: childId)
            .filter { record in
                guard let month else { return true }
                return formatter.string(from: record.analyzedAt) == month
            }
            .compactMap(buildHistoryItem(from:))
    }

    func loadResult(sessionId: UUID) -> PipelineResult? {
        guard let entry = load(sessionId: sessionId) else { return nil }
        return entry.result
    }

    func dailyInsightCache(childId: UUID, dayKey: String, sessionSignature: String) -> InsightSummaryPair? {
        var descriptor = FetchDescriptor<DailyInsightCacheRecord>(
            predicate: #Predicate {
                $0.childId == childId && $0.dayKey == dayKey && $0.sessionSignature == sessionSignature
            }
        )
        descriptor.fetchLimit = 1
        guard let record = try? modelContext.fetch(descriptor).first else { return nil }
        return InsightSummaryPair.fromCached(short: record.summary, detail: record.detailSummary)
    }

    func saveDailyInsightCache(
        childId: UUID,
        dayKey: String,
        sessionSignature: String,
        summary: InsightSummaryPair
    ) {
        var descriptor = FetchDescriptor<DailyInsightCacheRecord>(
            predicate: #Predicate {
                $0.childId == childId && $0.dayKey == dayKey && $0.sessionSignature == sessionSignature
            }
        )
        descriptor.fetchLimit = 1
        let existing = try? modelContext.fetch(descriptor).first
        if let existing {
            existing.summary = summary.shortSummary
            existing.detailSummary = summary.detailSummary
            existing.builtAt = Date()
        } else {
            let record = DailyInsightCacheRecord(
                childId: childId,
                dayKey: dayKey,
                sessionSignature: sessionSignature,
                summary: summary.shortSummary,
                detailSummary: summary.detailSummary
            )
            modelContext.insert(record)
        }
        try? modelContext.save()
    }

    struct WeeklyInsightCached: Equatable {
        let shortSummary: String
        let detailSummary: String
        let weeklySuggestion: String
        let followUpOptions: [String]
    }

    func weeklyInsightCache(
        childId: UUID,
        weekKey: String,
        sessionSignature: String
    ) -> WeeklyInsightCached? {
        var descriptor = FetchDescriptor<WeeklyInsightCacheRecord>(
            predicate: #Predicate {
                $0.childId == childId
                    && $0.weekKey == weekKey
                    && $0.sessionSignature == sessionSignature
            }
        )
        descriptor.fetchLimit = 1
        guard let record = try? modelContext.fetch(descriptor).first else { return nil }
        let followUps = Self.decodeStringArray(record.followUpOptionsJSON)
        return WeeklyInsightCached(
            shortSummary: record.aiSummary,
            detailSummary: record.aiSummaryDetail,
            weeklySuggestion: record.weeklySuggestion,
            followUpOptions: followUps.isEmpty ? WeeklyInsightOutput.defaultFollowUpOptions : followUps
        )
    }

    func clearWeeklyInsightCaches(for childId: UUID, weekKey: String) {
        let childIdValue = childId
        let weekKeyValue = weekKey
        var descriptor = FetchDescriptor<WeeklyInsightCacheRecord>(
            predicate: #Predicate {
                $0.childId == childIdValue && $0.weekKey == weekKeyValue
            }
        )
        guard let records = try? modelContext.fetch(descriptor) else { return }
        for record in records {
            modelContext.delete(record)
        }
        try? modelContext.save()
    }

    func clearSuggestionTry(childId: UUID, weekKey: String) {
        let childIdValue = childId
        let weekKeyValue = weekKey
        var descriptor = FetchDescriptor<WeeklySuggestionTryRecord>(
            predicate: #Predicate {
                $0.childId == childIdValue && $0.weekKey == weekKeyValue
            }
        )
        guard let records = try? modelContext.fetch(descriptor) else { return }
        for record in records {
            modelContext.delete(record)
        }
        try? modelContext.save()
    }

    func saveWeeklyInsightCache(
        childId: UUID,
        weekKey: String,
        sessionSignature: String,
        output: WeeklyInsightOutput
    ) {
        let followUpJSON = Self.encodeStringArray(output.followUpOptions)
        var descriptor = FetchDescriptor<WeeklyInsightCacheRecord>(
            predicate: #Predicate {
                $0.childId == childId
                    && $0.weekKey == weekKey
                    && $0.sessionSignature == sessionSignature
            }
        )
        descriptor.fetchLimit = 1
        let existing = try? modelContext.fetch(descriptor).first
        if let existing {
            existing.aiSummary = output.shortSummary
            existing.aiSummaryDetail = output.detailSummary
            existing.weeklySuggestion = output.weeklySuggestion
            existing.followUpOptionsJSON = followUpJSON
            existing.builtAt = Date()
        } else {
            let record = WeeklyInsightCacheRecord(
                childId: childId,
                weekKey: weekKey,
                sessionSignature: sessionSignature,
                aiSummary: output.shortSummary,
                aiSummaryDetail: output.detailSummary,
                weeklySuggestion: output.weeklySuggestion,
                followUpOptionsJSON: followUpJSON
            )
            modelContext.insert(record)
        }
        try? modelContext.save()
    }

    func saveSuggestionTry(
        childId: UUID,
        weekKey: String,
        suggestion: String,
        tried: Bool,
        followUpOptions: [String],
        followUpSelection: String?,
        note: String?
    ) throws {
        let followUpJSON = Self.encodeStringArray(followUpOptions)
        var descriptor = FetchDescriptor<WeeklySuggestionTryRecord>(
            predicate: #Predicate {
                $0.childId == childId && $0.weekKey == weekKey
            }
        )
        descriptor.fetchLimit = 1
        let existing = try? modelContext.fetch(descriptor).first
        if let existing {
            existing.suggestion = suggestion
            existing.tried = tried
            existing.followUpOptionsJSON = followUpJSON
            existing.followUpSelection = followUpSelection
            existing.note = note
            existing.savedAt = Date()
        } else {
            let record = WeeklySuggestionTryRecord(
                childId: childId,
                weekKey: weekKey,
                suggestion: suggestion,
                tried: tried,
                followUpOptionsJSON: followUpJSON,
                followUpSelection: followUpSelection,
                note: note
            )
            modelContext.insert(record)
        }
        try modelContext.save()
    }

    func fetchSuggestionTryRecords(for childId: UUID) -> [WeeklySuggestionTryRecord] {
        let childIdValue = childId
        var descriptor = FetchDescriptor<WeeklySuggestionTryRecord>(
            predicate: #Predicate { $0.childId == childIdValue },
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchSuggestionTry(childId: UUID, weekKey: String) -> SavedSuggestionTry? {
        let childIdValue = childId
        let weekKeyValue = weekKey
        var descriptor = FetchDescriptor<WeeklySuggestionTryRecord>(
            predicate: #Predicate {
                $0.childId == childIdValue && $0.weekKey == weekKeyValue
            }
        )
        descriptor.fetchLimit = 1
        guard let record = try? modelContext.fetch(descriptor).first else { return nil }
        return SavedSuggestionTry(
            suggestion: record.suggestion,
            tried: record.tried,
            followUpSelection: record.followUpSelection,
            note: record.note
        )
    }

    private static func encodeStringArray(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private static func decodeStringArray(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return values
    }

    private func fetchRecords(for childId: UUID) -> [SessionAnalysisRecord] {
        let childIdValue = childId
        var descriptor = FetchDescriptor<SessionAnalysisRecord>(
            predicate: #Predicate { $0.childId == childIdValue },
            sortBy: [SortDescriptor(\.analyzedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func cacheEntry(from record: SessionAnalysisRecord) -> SessionAnalysisCacheEntry? {
        switch record.status {
        case .completed:
            guard let stored = decodeStoredPipelineResult(from: record) else {
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

    private func fetchRecord(sessionId: UUID) throws -> SessionAnalysisRecord? {
        var descriptor = FetchDescriptor<SessionAnalysisRecord>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func decodeStoredPipelineResult(from record: SessionAnalysisRecord) -> StoredPipelineResult? {
        guard let payloadJSON = record.payloadJSON,
              let data = payloadJSON.data(using: .utf8),
              let stored = try? JSONDecoder().decode(StoredPipelineResult.self, from: data) else {
            return nil
        }
        return stored
    }

    private func buildHistoryItem(from record: SessionAnalysisRecord) -> SessionAnalysisHistoryItem? {
        switch record.status {
        case .failed:
            return SessionAnalysisHistoryItem(
                sessionId: record.sessionId,
                childId: record.childId,
                analyzedAt: record.analyzedAt,
                summaryPreview: nil,
                dominantCategory: nil,
                screenCount: 0,
                errorMessage: record.errorMessage ?? "Analysis failed."
            )
        case .completed:
            var summary = record.summaryPreview
            var category = record.dominantCategory
            var count = record.screenCount

            if summary == nil || category == nil || count == 0,
               let stored = decodeStoredPipelineResult(from: record) {
                summary = summary ?? stored.summary
                category = category ?? (stored.resolvedCategoryBreakdown.dominantDisplayLabel ?? stored.category)
                count = max(count, stored.screens.count)
            }

            return SessionAnalysisHistoryItem(
                sessionId: record.sessionId,
                childId: record.childId,
                analyzedAt: record.analyzedAt,
                summaryPreview: summary,
                dominantCategory: category,
                screenCount: count,
                errorMessage: nil
            )
        }
    }
}
