//
//  OfflineActivityView.swift
//  team-10-c3
//
//  Created by Huy Tran on 29/05/26.
//

import SwiftUI

struct OfflineActivityView: View {
    @State private var selectedActivity: ActivityItem?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(ActivityLibrary.allSections) { section in
                    VStack(alignment: .leading, spacing: 16) {
                        Text(section.title)
                            .font(.title3.bold())
                            .padding(.horizontal)

                        ForEach(section.activities) { activity in
                            ActivityCardView(activity: activity) {
                                selectedActivity = activity
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Offline Activity")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedActivity) { activity in
            OfflineActivityDetailView(activity: activity)
        }
    }
}

struct ActivityCardView: View {
    let activity: ActivityItem
    var onTryGameTapped: () -> Void

    var body: some View {
        CardView(minHeight: 309) {
            VStack(alignment: .leading, spacing: 12) {
                Image(activity.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 6) {
                    Text(activity.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(activity.shortDescription)
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    if let subtitle = activity.subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                
                PrimaryButton(title: "Try This Game") {
                    onTryGameTapped()
                }
            }
            .padding()
        }
    }
}

#Preview {
    NavigationStack {
        OfflineActivityView()
    }
}

#Preview {
    NavigationStack {
        OfflineActivityView()
    }
}
