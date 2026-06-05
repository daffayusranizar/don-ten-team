//
//  SessionScreenBreakdownView.swift
//  team-10-c3
//

import SwiftUI

/// List of analyzed screen segments for the current session (in-memory only).
struct SessionScreenBreakdownView: View {
    let screens: [ScreenBreakdownItem]

    @State private var selectedScreen: ScreenBreakdownItem?

    var body: some View {
        List {
            Section {
                ForEach(Array(screens.enumerated()), id: \.element.id) { index, screen in
                    Button {
                        selectedScreen = screen
                    } label: {
                        TimelineRowView(
                            item: screen,
                            previousTranscript: index > 0
                                ? screens[index - 1].meaningfulAudioTranscript
                                : nil
                        )
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("Each entry is about 3 seconds of the recording. Analysis is saved on this device and survives app restarts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.uiBackground.ignoresSafeArea())
        .navigationTitle("Screen breakdown")
        .navigationSubtitle("\(screens.count) screens analyzed")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationDestination(item: $selectedScreen) { screen in
            SessionScreenDetailView(screen: screen)
        }
    }
}

#Preview {
    NavigationStack {
        SessionScreenBreakdownView(screens: [.preview, ScreenBreakdownItem(
            id: 1,
            timestampLabel: "1:06",
            timestampSeconds: 66,
            categoryLabel: "Entertainment",
            contentSummary: "Entertainment · Spoken: Let's go to the next level.",
            videoMatchedPrompt: "Fast-paced gameplay montage",
            matchedPrompt: nil,
            creatorHandle: nil,
            confidence: 0.71,
            thumbnail: nil,
            bottomCropThumbnail: nil,
            audioTranscript: nil,
            audioTone: nil,
            audioLabel: nil
        )])
    }
}
