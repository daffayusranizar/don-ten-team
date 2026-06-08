//
//  NeedAttentionView.swift
//  team-10-c3
//
//  Created by Daffa Yuranizar Arrifi on 05/06/26.
//

import SwiftUI

struct NeedAttentionView: View {
    let period: Period

    var body: some View {
        ScrollView {
            Text("Your child's content consumption pattern has changed noticeably this week. ")
                .font(.bodyRegular)
                .padding([.leading])

            LazyVStack(spacing: 20) {

                LineChartView()

                SummaryCardView(period: period, isNeedAttention: false)

                CardView(minHeight: 205) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.18))
                                        .frame(width: 24, height: 24)

                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.red)
                                }

                                Text("Needs your attention")
                                    .font(.heading6)

                                Spacer()
                            }
                        }

                        Text(
                            "AI detected a significant shift in content preferences. Entertainment content became the most-viewed category this week, replacing educational content as the dominant viewing preference. This differs substantially from your child's typical content consumption pattern."
                        )
                        .font(.bodyRegular)
                        .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.24))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Need Attention")
                    .font(.heading5)
            }
        }
        .toolbarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
    }
}

#Preview {
    NavigationStack {
        NeedAttentionView(period: .daily)
    }
}
