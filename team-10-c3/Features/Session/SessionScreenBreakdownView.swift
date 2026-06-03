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
                ForEach(screens) { screen in
                    Button {
                        selectedScreen = screen
                    } label: {
                        TimelineRowView(item: screen)
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("Each entry is about 3 seconds of the recording. Analysis is available until you start a new session.")
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
            contentSummary: "Fast-paced gameplay montage.",
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
