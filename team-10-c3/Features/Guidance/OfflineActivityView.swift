//
//  OfflineActivityView.swift
//  team-10-c3
//
//  Created by Huy Tran on 29/05/26.
//

import SwiftUI

// MARK: - Models

struct OfflineActivity: Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let overview: String
    let steps: [String]

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        overview: String,
        steps: [String]
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.overview = overview
        self.steps = steps
    }
}

struct ActivityCategory: Identifiable {
    let id = UUID()
    let name: String
    let activities: [OfflineActivity]
}

// MARK: - View

struct OfflineActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedActivity: OfflineActivity?

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            offlineActivityEmptyState
        }
        .padding(.horizontal, 30)
        .background(.uiBackground)
        .foregroundStyle(.textPrimary)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedActivity) { activity in
            OfflineActivityDetailView(activity: activity)
                .presentationDetents([.large])
        }
    }

    private var offlineActivityEmptyState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 40)

            Image(systemName: "figure.play")
                .font(.system(size: 48))
                .foregroundStyle(.primaryMediumBlue)

            Text("No offline activities yet")
                .font(.system(size: 22, weight: .semibold))

            Text("Suggested offline activities will appear here after guidance sessions.")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

    private var toolbar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding()
                    .background(Circle().fill(.primaryDarkBlue))
            }

            Spacer()

            Text("Offline Activity")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 56, height: 56)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        OfflineActivityView()
    }
}
