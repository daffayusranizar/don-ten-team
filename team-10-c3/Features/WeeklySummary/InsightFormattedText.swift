//
//  InsightFormattedText.swift
//  team-10-c3
//

import SwiftUI

struct InsightFormattedText: View {
    let text: String

    private var sections: [InsightDetailLayout.Section] {
        InsightDetailLayout.sections(from: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if sections.isEmpty {
                Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.bodyRegular)
                    .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.24))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    sectionView(section)

                    if index < sections.count - 1 {
                        Divider()
                            .overlay(Color(red: 0.88, green: 0.89, blue: 0.92))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func sectionView(_ section: InsightDetailLayout.Section) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(section)

            ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.bodyRegular)
                    .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.24))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !section.bullets.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(section.bullets) { bullet in
                        bulletRow(bullet, accent: accentColor(for: section.kind))
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ section: InsightDetailLayout.Section) -> some View {
        HStack(spacing: 8) {
            Image(systemName: iconName(for: section.kind))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentColor(for: section.kind))
                .frame(width: 24, height: 24)
                .background(accentColor(for: section.kind).opacity(0.12))
                .clipShape(Circle())

            Text(section.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.14, green: 0.15, blue: 0.22))
        }
    }

    @ViewBuilder
    private func bulletRow(_ bullet: InsightDetailLayout.Bullet, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(accent)
                .frame(width: 7, height: 7)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 4) {
                if let label = bullet.label, !label.isEmpty {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.14, green: 0.15, blue: 0.22))
                }

                if !bullet.text.isEmpty {
                    Text(bullet.text)
                        .font(.bodyRegular)
                        .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.24))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func iconName(for kind: InsightDetailLayout.Section.Kind) -> String {
        switch kind {
        case .overview: return "doc.text"
        case .topics: return "arrow.triangle.2.circlepath"
        case .attention: return "eye"
        case .reportEvidence: return "checkmark.seal"
        case .concerns: return "exclamationmark.triangle"
        case .recommendation: return "lightbulb"
        case .evidenceNotes: return "list.bullet.rectangle"
        }
    }

    private func accentColor(for kind: InsightDetailLayout.Section.Kind) -> Color {
        switch kind {
        case .overview: return Color(red: 0.22, green: 0.45, blue: 0.85)
        case .topics: return Color(red: 0.35, green: 0.55, blue: 0.95)
        case .attention: return Color(red: 0.55, green: 0.38, blue: 0.92)
        case .reportEvidence: return Color(red: 0.18, green: 0.62, blue: 0.48)
        case .concerns: return Color(red: 0.95, green: 0.45, blue: 0.35)
        case .recommendation: return Color(red: 0.95, green: 0.62, blue: 0.18)
        case .evidenceNotes: return Color(red: 0.28, green: 0.48, blue: 0.72)
        }
    }
}

#Preview("Messy LLM output") {
    ScrollView {
        InsightFormattedText(
            text: """
            The child requested to help a character in the game. This suggests a friendly and cooperative interaction. The message quality appears neutral. We recommend monitoring Y's screen activity. Evidence notes: 1. Content Type: Primarily entertainment. 2. Spoken Audio: Personas from a game, including Dionysus and Sur, are heard. Yano-sik is also mentioned. 3. Visual Content: Not detailed in the notes. 4. On-screen Text/OCR: Not detailed in the notes. 5. Attention Signals: The child requested to help a character in the game. 6. Message Quality: Neutral. 7. Concerns: None detected. 8. Recommendation: Monitor Y's screen activity.
            """
        )
        .padding(24)
    }
    .background(.uiBackground)
}

#Preview("Numbered evidence artifacts") {
    ScrollView {
        InsightFormattedText(
            text: """
            Overall, looking at the evidence, we recommend that you to do this: Monitor Y's screen activity and ensure it remains within appropriate boundaries.Evidence notes:1. Content Type: Primarily entertainment. 2. Spoken Audio: Personas from a game are heard, including Dionysus, Sur, and Yano-sik, with a request for help from another user. 3. Visual Content: Not detailed in the notes. 4. On-screen Text/OCR: Not provided in the notes. 5. Message Quality: Neutral/friendly. 6. Concerns: There are no specific concerns mentioned in the notes. 7. Attention Signals: The child appears drawn to the game. 8. Recurring Themes: Game-related interactions and personas. 8.
            """
        )
        .padding(24)
    }
    .background(.uiBackground)
}
