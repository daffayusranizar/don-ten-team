//
//  SessionScreenDetailView.swift
//  team-10-c3
//

import SwiftUI

struct SessionScreenDetailView: View {
    let screen: ScreenBreakdownItem

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                SessionResultCard(
                    icon: "clock.fill",
                    iconColor: .primaryMediumBlue,
                    title: "When",
                    content: "\(screen.timestampLabel) into the session"
                )

                SessionResultCard(
                    icon: "chart.bar.fill",
                    iconColor: .decorativeSkyBlue,
                    title: "Category",
                    content: categoryContent
                )

                if let summary = screen.contentSummary, !summary.isEmpty {
                    SessionResultCard(
                        icon: "text.alignleft",
                        iconColor: .primaryMediumBlue,
                        title: "What we saw",
                        content: summary
                    )
                }

                if screen.hasScreenshots {
                    screenshotsSection
                }

                if screen.hasAudioDetails || screen.meaningfulAudioTranscript != nil || screen.isSilentOrUnreadableTone {
                    SessionResultCard(
                        icon: "waveform",
                        iconColor: .decorativeSunnyYellow,
                        title: "What we heard",
                        content: audioContent
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.uiBackground.ignoresSafeArea())
        .foregroundStyle(.textPrimary)
        .navigationTitle(screen.timestampLabel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var categoryContent: String {
        if let confidence = screen.confidencePercentText {
            return "\(screen.categoryLabel)\n\(confidence)"
        }
        return screen.categoryLabel
    }

    private var audioContent: String {
        var lines: [String] = []
        if let label = screen.audioLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            lines.append("Label: \(label)")
        }

        let transcript = screen.meaningfulAudioTranscript

        if let transcript {
            lines.append("Transcript: \(transcript)")
        } else if screen.isSilentOrUnreadableTone {
            lines.append(
                "App audio wasn’t clear in this clip (Screen Time captures app sound only, not the microphone)."
            )
        }

        if let friendlyTone = SessionToneSummarizer.frameDisplayTone(
            audioTone: screen.audioTone,
            transcript: screen.audioTranscript
        ) {
            lines.append("Tone: \(friendlyTone)")
        }

        return lines.joined(separator: "\n\n")
    }

    @ViewBuilder
    private var screenshotsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.decorativeCoralPink)
                    .frame(width: 32, height: 32)
                    .background(Color.decorativeCoralPink.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                Text("Screenshot")
                    .font(.system(size: 15, weight: .semibold))
            }

            VStack(spacing: 12) {
                if let thumbnail = screen.thumbnail {
                    screenshotImage(thumbnail, caption: "Full frame")
                }
                if let crop = screen.bottomCropThumbnail {
                    screenshotImage(crop, caption: "Caption area")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.uiSurface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func screenshotImage(_ uiImage: UIImage, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

#Preview {
    NavigationStack {
        SessionScreenDetailView(screen: .preview)
    }
}
