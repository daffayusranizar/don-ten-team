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

                if let creator = screen.creatorHandle, !creator.isEmpty {
                    SessionResultCard(
                        icon: "person.wave.2.fill",
                        iconColor: .decorativeMintGreen,
                        title: "Creator",
                        content: creator
                    )
                }

                if screen.hasScreenshots {
                    screenshotsSection
                }

                if screen.hasAudioDetails {
                    SessionResultCard(
                        icon: "waveform",
                        iconColor: .decorativeSunnyYellow,
                        title: "Audio",
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
        if let tone = screen.audioTone?.trimmingCharacters(in: .whitespacesAndNewlines), !tone.isEmpty {
            lines.append("Tone: \(tone)")
        }
        if let raw = screen.audioTranscript?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty {
            lines.append("Transcript: \(raw)")
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
