//
//  OfflineActivityDetailView.swift
//  team-10-c3
//
//  Created by Huy Tran on 29/05/26.
//

import SwiftUI

struct OfflineActivityDetailView: View {
    let activity: ActivityItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(activity.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 359, height: 190)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 20) {
                        detailSectionTitle("Description")

                        Text(activity.detailDescription)
                            .font(.bodyRegular)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)

                        detailSectionTitle(activity.howToTitle)

                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(Array(activity.howTo.enumerated()), id: \.offset) { index, item in
                                numberedRow(number: index + 1, text: item)
                            }
                        }

                        detailSectionTitle(activity.tipsTitle)

                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(Array(activity.tips.enumerated()), id: \.offset) { index, item in
                                numberedRow(number: index + 1, text: item)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                }
            }
            .navigationTitle(activity.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func detailSectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.heading6)
            .foregroundStyle(.primary)
    }

    private func numberedRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(number).")
                .font(.bodyRegular)
                .foregroundStyle(.primary)

            Text(text)
                .font(.bodyRegular)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    OfflineActivityDetailView(activity: ActivityLibrary.allActivities[0])
}
