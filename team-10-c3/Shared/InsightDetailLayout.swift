//
//  InsightDetailLayout.swift
//  team-10-c3
//

import Foundation

enum InsightDetailLayout {
    struct Bullet: Identifiable, Equatable, Sendable {
        let id = UUID()
        let label: String?
        let text: String
    }

    struct Section: Identifiable, Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            case overview
            case topics
            case attention
            case reportEvidence
            case concerns
            case recommendation
            case evidenceNotes
        }

        let id = UUID()
        let kind: Kind
        let title: String
        let paragraphs: [String]
        let bullets: [Bullet]
    }

    private struct Marker {
        let needle: String
        let kind: Section.Kind
        let title: String
        let isMajorSection: Bool
    }

    private static let majorMarkers: [Marker] = [
        Marker(
            needle: "Topics that are repeated most often are:",
            kind: .topics,
            title: "Topics repeated most often",
            isMajorSection: true
        ),
        Marker(
            needle: "What Appears To Hold Attention:",
            kind: .attention,
            title: "What appears to hold attention",
            isMajorSection: true
        ),
        Marker(
            needle: "The evidence of this report are:",
            kind: .reportEvidence,
            title: "Evidence from this report",
            isMajorSection: true
        ),
        Marker(
            needle: "The evidencce of this report are:",
            kind: .reportEvidence,
            title: "Evidence from this report",
            isMajorSection: true
        ),
        Marker(
            needle: "We concern about that these things:",
            kind: .concerns,
            title: "Things we are concerned about",
            isMajorSection: true
        ),
        Marker(
            needle: "Overall, looking at the evidence, we recommend that you to do this:",
            kind: .recommendation,
            title: "Our recommendation",
            isMajorSection: true
        ),
        Marker(
            needle: "Overall, looking at the evidence, we recommend that you:",
            kind: .recommendation,
            title: "Our recommendation",
            isMajorSection: true
        ),
        Marker(
            needle: "Overall, looking at the evidence, we recommend:",
            kind: .recommendation,
            title: "Our recommendation",
            isMajorSection: true
        ),
        Marker(
            needle: "Evidence notes:",
            kind: .evidenceNotes,
            title: "Evidence notes",
            isMajorSection: true
        ),
    ]

    private static let evidenceFieldLabels = [
        "Content Type:",
        "Spoken Audio:",
        "Visual Content:",
        "On-screen Text/OCR:",
        "Attention Signals:",
        "Message Quality:",
        "Recurring Themes:",
        "Concerns:",
        "Recommendation:",
    ]

    static func sections(from raw: String) -> [Section] {
        let prepared = prepare(raw)
        guard !prepared.isEmpty else { return [] }

        let hits = findMajorMarkers(in: prepared)
        guard !hits.isEmpty else {
            return [Section(kind: .overview, title: "Summary", paragraphs: [prepared], bullets: [])]
        }

        var result: [Section] = []

        let introEnd = hits[0].range.lowerBound
        let intro = String(prepared[..<introEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !intro.isEmpty {
            result.append(Section(kind: .overview, title: "Summary", paragraphs: paragraphs(from: intro), bullets: []))
        }

        for (index, hit) in hits.enumerated() {
            let bodyStart = hit.range.upperBound
            let bodyEnd = index + 1 < hits.count ? hits[index + 1].range.lowerBound : prepared.endIndex
            let body = String(prepared[bodyStart..<bodyEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }

            if hit.marker.kind == .evidenceNotes {
                result.append(Section(
                    kind: .evidenceNotes,
                    title: hit.marker.title,
                    paragraphs: [],
                    bullets: evidenceBullets(from: body)
                ))
            } else {
                result.append(Section(
                    kind: hit.marker.kind,
                    title: hit.marker.title,
                    paragraphs: paragraphs(from: body),
                    bullets: []
                ))
            }
        }

        return result
    }

    // MARK: - Preprocessing

    private static func prepare(_ text: String) -> String {
        var result = InsightSummaryParser.normalize(text)

        for header in ["SHORT_SUMMARY:", "SUMMARY:", "DETAIL:", "SUGGESTION:", "FOLLOWUP_OPTIONS:", "FOLLOW_UP_OPTIONS:"] {
            result = result.replacingOccurrences(of: header, with: "", options: [.caseInsensitive])
        }

        result = result
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "*", with: "")

        result = result.replacingOccurrences(
            of: #"(?<=\.)([A-Z])"#,
            with: ". $1",
            options: .regularExpression
        )

        let needles = majorMarkers.map(\.needle) + evidenceFieldLabels
        for needle in needles.sorted(by: { $0.count > $1.count }) {
            result = insertBreaks(before: needle, in: result)
        }

        if let regex = try? NSRegularExpression(pattern: #"(?<!\n)\s+(\d+\.\s)"#) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "\n$1")
        }

        result = result.replacingOccurrences(
            of: #"(?m)^(\d+\.)\s+"#,
            with: "\n$1 ",
            options: .regularExpression
        )

        result = result.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func insertBreaks(before needle: String, in text: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: needle)
        guard let regex = try? NSRegularExpression(
            pattern: "(?<!\\n)(?<=[^\\n])\(escaped)",
            options: [.caseInsensitive]
        ) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "\n\n\(needle)")
    }

    // MARK: - Parsing helpers

    private struct MarkerHit {
        let marker: Marker
        let range: Range<String.Index>
    }

    private static func findMajorMarkers(in text: String) -> [MarkerHit] {
        var hits: [MarkerHit] = []

        for marker in majorMarkers {
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let range = text.range(of: marker.needle, options: [.caseInsensitive], range: searchStart..<text.endIndex) {
                hits.append(MarkerHit(marker: marker, range: range))
                searchStart = range.upperBound
            }
        }

        hits.sort { $0.range.lowerBound < $1.range.lowerBound }

        var deduped: [MarkerHit] = []
        for hit in hits {
            if let last = deduped.last, hit.range.lowerBound < last.range.upperBound {
                continue
            }
            deduped.append(hit)
        }

        return deduped
    }

    private static func paragraphs(from text: String) -> [String] {
        text
            .components(separatedBy: "\n\n")
            .map { $0.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func evidenceBullets(from text: String) -> [Bullet] {
        var prepared = sanitizeEvidenceBlock(text)
        let labelHits = findEvidenceLabelHits(in: prepared)

        if !labelHits.isEmpty {
            var bullets: [Bullet] = []
            for (index, hit) in labelHits.enumerated() {
                let displayLabel = String(hit.label.dropLast())
                let valueStart = hit.range.upperBound
                let valueEnd = index + 1 < labelHits.count
                    ? labelHits[index + 1].range.lowerBound
                    : prepared.endIndex
                let value = cleanEvidenceValue(String(prepared[valueStart..<valueEnd]))
                guard !value.isEmpty || !displayLabel.isEmpty else { continue }
                bullets.append(Bullet(label: displayLabel, text: value))
            }
            return bullets.filter { !isOrphanListMarker($0) }
        }

        return legacyLineBullets(from: prepared).filter { !isOrphanListMarker($0) }
    }

    private struct LabelHit {
        let label: String
        let range: Range<String.Index>
    }

    private static func findEvidenceLabelHits(in text: String) -> [LabelHit] {
        var hits: [LabelHit] = []

        for label in evidenceFieldLabels {
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let range = text.range(of: label, options: [.caseInsensitive], range: searchStart..<text.endIndex) {
                hits.append(LabelHit(label: label, range: range))
                searchStart = range.upperBound
            }
        }

        hits.sort { $0.range.lowerBound < $1.range.lowerBound }

        var deduped: [LabelHit] = []
        for hit in hits {
            if let last = deduped.last, hit.range.lowerBound < last.range.upperBound {
                continue
            }
            deduped.append(hit)
        }
        return deduped
    }

    private static func sanitizeEvidenceBlock(_ text: String) -> String {
        var result = text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        result = result.replacingOccurrences(
            of: #"(?<=\.)([A-Z])"#,
            with: ". $1",
            options: .regularExpression
        )

        let labelNames = evidenceFieldLabels
            .map { NSRegularExpression.escapedPattern(for: String($0.dropLast())) }
            .joined(separator: "|")

        if !labelNames.isEmpty {
            result = result.replacingOccurrences(
                of: #"\s+\d+\.\s+(?=(?:\#(labelNames)):)"#,
                with: "\n\n",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        for label in evidenceFieldLabels {
            let escapedLabel = NSRegularExpression.escapedPattern(for: label)
            result = result.replacingOccurrences(
                of: #"\d+\.\s*\#(escapedLabel)"#,
                with: label,
                options: [.regularExpression, .caseInsensitive]
            )
            result = insertBreaks(before: label, in: result)
        }

        result = result.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanEvidenceValue(_ value: String) -> String {
        var result = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let regex = try? NSRegularExpression(pattern: #"(?:\.\s*)?\d+\.\s*$"#) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isOrphanListMarker(_ bullet: Bullet) -> Bool {
        if bullet.label != nil { return false }
        let trimmed = bullet.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(of: #"^\d+\.?$"#, options: .regularExpression) != nil
    }

    private static func legacyLineBullets(from prepared: String) -> [Bullet] {
        let lines = prepared
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var bullets: [Bullet] = []

        for line in lines {
            if line.range(of: #"^\d+\.\s*$"#, options: .regularExpression) != nil {
                continue
            }

            if let bullet = numberedEvidenceBullet(from: line) {
                bullets.append(bullet)
                continue
            }

            if let bullet = labeledEvidenceBullet(from: line) {
                bullets.append(bullet)
                continue
            }

            if let lastIndex = bullets.indices.last {
                let last = bullets[lastIndex]
                bullets[lastIndex] = Bullet(
                    label: last.label,
                    text: cleanEvidenceValue([last.text, line].joined(separator: " "))
                )
            } else {
                bullets.append(Bullet(label: nil, text: cleanEvidenceValue(line)))
            }
        }

        return bullets
    }

    private static func numberedEvidenceBullet(from line: String) -> Bullet? {
        let pattern = #"^\d+\.\s*(?:\*)?\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)),
              match.numberOfRanges > 1,
              let contentRange = Range(match.range(at: 1), in: line) else {
            return nil
        }

        let content = cleanEvidenceValue(String(line[contentRange]))
        guard !content.isEmpty else { return nil }
        return labeledEvidenceBullet(from: content) ?? Bullet(label: nil, text: content)
    }

    private static func labeledEvidenceBullet(from line: String) -> Bullet? {
        for label in evidenceFieldLabels {
            guard line.range(of: label, options: [.caseInsensitive, .anchored]) != nil else { continue }
            let trimmedLabel = String(label.dropLast())
            let valueStart = line.index(line.startIndex, offsetBy: label.count)
            let value = cleanEvidenceValue(String(line[valueStart...]))
            guard !value.isEmpty else { return nil }
            return Bullet(label: trimmedLabel, text: value)
        }
        return nil
    }
}
