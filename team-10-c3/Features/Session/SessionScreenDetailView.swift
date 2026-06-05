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
                ForEach(screen.analysisFields) { field in
                    SessionResultCard(
                        icon: field.icon,
                        iconColor: field.iconColor,
                        title: field.title,
                        content: field.content
                    )
                }

                if screen.hasScreenshots {
                    screenshotsSection
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
                    screenshotImage(thumbnail, caption: "Screenshot")
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

private struct ScreenAnalysisField: Identifiable {
    let id: String
    let icon: String
    let iconColor: Color
    let title: String
    let content: String
}

extension ScreenBreakdownItem {
    fileprivate var analysisFields: [ScreenAnalysisField] {
        var fields: [ScreenAnalysisField] = [
            ScreenAnalysisField(
                id: "when",
                icon: "clock.fill",
                iconColor: .primaryMediumBlue,
                title: "When",
                content: "\(timestampLabel) into the session (\(Int(timestampSeconds))s)"
            ),
            ScreenAnalysisField(
                id: "category",
                icon: "chart.bar.fill",
                iconColor: .decorativeSkyBlue,
                title: "Category",
                content: categoryDetailText
            )
        ]

        if let visual = onScreenContent {
            fields.append(ScreenAnalysisField(
                id: "visual",
                icon: "eye.fill",
                iconColor: .decorativeMintGreen,
                title: "On-screen content",
                content: visual
            ))
        }

        if let summary = trimmed(contentSummary) {
            fields.append(ScreenAnalysisField(
                id: "summary",
                icon: "text.alignleft",
                iconColor: .primaryMediumBlue,
                title: "Segment summary",
                content: summary
            ))
        }

        return fields
    }

    private var categoryDetailText: String {
        var lines = [categoryLabel]
        if let confidencePercentText {
            lines.append(confidencePercentText)
        }
        return lines.joined(separator: "\n")
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

#Preview {
    NavigationStack {
        SessionScreenDetailView(screen: .preview)
    }
}
