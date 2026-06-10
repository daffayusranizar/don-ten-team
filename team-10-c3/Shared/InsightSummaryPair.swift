//
//  InsightSummaryPair.swift
//  team-10-c3
//

import Foundation

struct InsightSummaryPair: Equatable, Sendable {
    let shortSummary: String
    let detailSummary: String

    static func fromLegacySingleSummary(_ text: String) -> InsightSummaryPair {
        if let parsed = InsightSummaryParser.parse(text) {
            return parsed
        }
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return InsightSummaryPair(shortSummary: "", detailSummary: "")
        }
        return InsightSummaryPair(
            shortSummary: InsightSummaryFormatting.shortExcerpt(from: cleaned),
            detailSummary: cleaned
        )
    }

    static func fromCached(short: String, detail: String?) -> InsightSummaryPair {
        if let detail, !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return InsightSummaryPair(shortSummary: short, detailSummary: detail)
        }
        return fromLegacySingleSummary(short)
    }
}

enum InsightSummaryFormatting {
    static func shortExcerpt(from text: String, maxLength: Int = 280) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let firstParagraph = trimmed
            .components(separatedBy: "\n\n")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed

        if firstParagraph.count <= maxLength {
            return firstParagraph
        }

        let prefix = String(firstParagraph.prefix(maxLength))
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace]) + "…"
        }
        return prefix + "…"
    }

    /// Normalizes model output for readable markdown rendering in the detail screen.
    static func formatForDisplay(_ text: String) -> String {
        var result = InsightSummaryParser.normalize(text)

        for header in ["SHORT_SUMMARY:", "SUMMARY:", "DETAIL:", "SUGGESTION:", "FOLLOWUP_OPTIONS:", "FOLLOW_UP_OPTIONS:"] {
            result = result.replacingOccurrences(
                of: header,
                with: "",
                options: [.caseInsensitive]
            )
        }

        result = result
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let sectionBreakLabels = [
            "Topics that are repeated most often are:",
            "What Appears To Hold Attention:",
            "The evidence of this report are:",
            "The evidencce of this report are:",
            "We concern about that these things:",
            "Evidence notes:",
            "Overall, looking at the evidence, we recommend that you to do this:",
            "Overall, looking at the evidence, we recommend that you:",
            "Overall, looking at the evidence, we recommend:",
        ]

        for label in sectionBreakLabels {
            let escaped = NSRegularExpression.escapedPattern(for: label)
            result = result.replacingOccurrences(
                of: "(?<!\\n)\\s*\(escaped)",
                with: "\n\n\(label)",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        result = result.replacingOccurrences(
            of: #"(?i)(Evidence notes:)\s*(\d+\.)"#,
            with: "$1\n\n$2",
            options: .regularExpression
        )

        if let regex = try? NSRegularExpression(pattern: #"(?<!\n)\s+(\d+\.\s)"#) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "\n$1")
        }

        result = result.replacingOccurrences(
            of: #"(?m)^(\d+\.)\s*\*\s+"#,
            with: "$1 ",
            options: .regularExpression
        )

        result = result.replacingOccurrences(
            of: #":\s*\*\s+"#,
            with: ":\n- ",
            options: .regularExpression
        )

        result = result.replacingOccurrences(
            of: #"(?<=\n)\*\s+"#,
            with: "- ",
            options: .regularExpression
        )

        result = result.replacingOccurrences(
            of: #"\*\s+(?=[A-Z])"#,
            with: "\n- ",
            options: .regularExpression
        )

        for label in sectionBreakLabels {
            let escaped = NSRegularExpression.escapedPattern(for: label)
            result = result.replacingOccurrences(
                of: "(?m)^\(escaped)$",
                with: "**\(label)**",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        result = result.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum InsightSummaryParser {
    private static let summarySectionNames = [
        "SHORT_SUMMARY",
        "SUMMARY",
        "DETAIL",
        "SUGGESTION",
        "FOLLOWUP_OPTIONS",
        "FOLLOW_UP_OPTIONS",
    ]

    static func parse(_ text: String) -> InsightSummaryPair? {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return nil }

        let blocks = extractBlocks(from: normalized)
        guard let short = blocks["SHORT_SUMMARY"] ?? blocks["SUMMARY"],
              !short.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let detail = blocks["DETAIL"] ?? short
        return InsightSummaryPair(
            shortSummary: cleanProse(short),
            detailSummary: cleanProse(detail)
        )
    }

    static func extractBlocks(from text: String) -> [String: String] {
        let pattern = "(?i)(SHORT_SUMMARY|SUMMARY|DETAIL|SUGGESTION|FOLLOWUP_OPTIONS|FOLLOW_UP_OPTIONS)\\s*:"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return [:] }

        var blocks: [String: String] = [:]
        for (index, match) in matches.enumerated() {
            guard match.numberOfRanges > 1,
                  let nameRange = Range(match.range(at: 1), in: text),
                  let headerRange = Range(match.range, in: text) else {
                continue
            }

            let name = String(text[nameRange]).uppercased()
            let contentStart = headerRange.upperBound
            let contentEnd: String.Index
            if index + 1 < matches.count, let nextHeader = Range(matches[index + 1].range, in: text) {
                contentEnd = nextHeader.lowerBound
            } else {
                contentEnd = text.endIndex
            }

            let content = String(text[contentStart..<contentEnd])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if blocks[name] == nil, !content.isEmpty {
                blocks[name] = content
            }
        }

        return blocks
    }

    static func normalize(_ text: String) -> String {
        var normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        for header in summarySectionNames {
            normalized = normalized.replacingOccurrences(
                of: #"\*\*\s*"# + header + #"\s*:\s*\*\*"#,
                with: "\(header):",
                options: [.regularExpression, .caseInsensitive]
            )
            normalized = normalized.replacingOccurrences(
                of: #"\*\*\s*"# + header + #"\s*:"#,
                with: "\(header):",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        normalized = normalized.replacingOccurrences(
            of: #"(?m)^\*\*\s*$"#,
            with: "",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(of: "**", with: "")

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cleanProse(_ text: String) -> String {
        text
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
