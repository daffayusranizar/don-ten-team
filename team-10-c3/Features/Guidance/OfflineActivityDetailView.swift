//
//  OfflineActivityDetailView.swift
//  team-10-c3
//
//  Created by Huy Tran on 29/05/26.
//

import SwiftUI

struct OfflineActivityDetailView: View {
    let activity: OfflineActivity

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sheetToolbar

                List {
                    Section {
                        VStack(alignment: .leading, spacing: 20) {
                            ActivityImagePlaceholder(height: 190, cornerRadius: 19, showLabel: true)
                            Text(activity.overview)
                                .font(.system(size: 15))
                                .foregroundStyle(.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }

                    Section {
                        ForEach(Array(activity.steps.enumerated()), id: \.offset) { index, step in
                            Text("\(index + 1). \(step)")
                                .font(.system(size: 15))
                                .foregroundStyle(.textPrimary)
                                .lineSpacing(13)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .padding(.horizontal, 21)
            .background(.uiBackground)
            .foregroundStyle(.textPrimary)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var sheetToolbar: some View {
        ZStack {
            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .padding()
                        .background(Circle().fill(.uiSurface))
                }
            }

            Text(activity.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 56)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    OfflineActivityDetailView(
        activity: OfflineActivity(
            title: "2 Person Football Game",
            description: "Play short football passing challenges together.",
            overview: "Stand a few steps apart and pass the ball back and forth.",
            steps: ["Stand 3–5 meters apart.", "Pass the ball gently.", "Count successful passes together."]
        )
    )
}
