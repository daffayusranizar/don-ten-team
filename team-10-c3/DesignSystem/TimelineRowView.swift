//
//  TimelineRowView.swift
//  team-10-c3
//

import SwiftUI

/// Per-screen row for session breakdown list.
struct TimelineRowView: View {
    let item: ScreenBreakdownItem
    var previousTranscript: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnailView

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.timestampLabel)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text(item.categoryLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                }

                if let summary = item.contentSummary, !summary.isEmpty {
                    Text("What we saw: \(summary)")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(heardLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let toneLine = toneLine {
                    Text(toneLine)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var heardLine: String {
        if let transcript = item.meaningfulAudioTranscript {
            if transcript == previousTranscript {
                return "Heard: (same as previous)"
            }
            return "Heard: \"\(transcript)\""
        }
        if item.isSilentOrUnreadableTone {
            return "Heard: (no clear app audio in this clip)"
        }
        return "Heard: (no clear app audio in this clip)"
    }

    private var toneLine: String? {
        guard item.hasAudioDetails, !item.isSilentOrUnreadableTone else { return nil }
        let tone = item.audioTone?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !tone.isEmpty else { return nil }
        if let friendly = SessionToneSummarizer.frameDisplayTone(
            audioTone: item.audioTone,
            transcript: item.audioTranscript
        ) {
            return "Tone: \(friendly)"
        }
        return "Tone: \(tone)"
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let image = item.thumbnail ?? item.bottomCropThumbnail {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.primaryMediumBlue.opacity(0.12))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 18))
                        .foregroundStyle(.primaryMediumBlue.opacity(0.55))
                }
        }
    }
}

#Preview {
    List {
        TimelineRowView(item: .preview)
    }
}
