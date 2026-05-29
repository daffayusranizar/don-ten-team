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

    static let footballGame = OfflineActivity(
        title: "2 Person Football Game",
        description: "Play short football passing challenges together to build teamwork, focus, and connection.",
        overview: """
            Grab a ball and stand a few steps apart with your child. Take turns passing, controlling, and kicking the ball back while counting your successful passes together. Keep the game light, fun, and encouraging to build teamwork, confidence, and quality bonding time.
            """,
        steps: [
            "Stand 3–5 meters apart facing each other.",
            "Use a soft football suitable for children.",
            "Parent passes the ball gently to the child.",
            "Child controls the ball, then passes it back.",
            "Count successful passes together without dropping the ball.",
            "After every 5 passes, take one step farther apart.",
            "Add fun challenges like one-touch passes or weaker-foot kicks.",
            "Encourage and celebrate every successful teamwork moment together."
        ]
    )
}

struct ActivityCategory: Identifiable {
    let id = UUID()
    let name: String
    let activities: [OfflineActivity]
}

private func footballGameInstances(count: Int) -> [OfflineActivity] {
    (0..<count).map { _ in
        OfflineActivity(
            title: OfflineActivity.footballGame.title,
            description: OfflineActivity.footballGame.description,
            overview: OfflineActivity.footballGame.overview,
            steps: OfflineActivity.footballGame.steps
        )
    }
}

private let mockCategories: [ActivityCategory] = [
    ActivityCategory(name: "Sports", activities: footballGameInstances(count: 2)),
    ActivityCategory(name: "Board Games", activities: footballGameInstances(count: 2))
]

// MARK: - View

struct OfflineActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedActivity: OfflineActivity?

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            List {
                ForEach(mockCategories) { category in
                    Section {
                        ForEach(category.activities) { activity in
                            OfflineActivityCard(
                                title: activity.title,
                                description: activity.description,
                                onTryTapped: { selectedActivity = activity }
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        }
                    } header: {
                        Text(category.name)
                            .font(.heading6)
                            .foregroundStyle(.textPrimary)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
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
