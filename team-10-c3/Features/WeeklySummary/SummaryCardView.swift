//
//  SummaryCardView.swift
//  team-10-c3
//
//  Created by Daffa Yuranizar Arrifi on 05/06/26.
//

import SwiftUI


struct SummaryCardView: View {
    let period: Period
    let isNeedAttention: Bool
    
    var body: some View {
        CardView(width: 346, height: 180) {
            VStack(spacing: 0) {
                if isNeedAttention {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 24, height: 24)

                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        Text("Needs your attention")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)

                        Spacer()
                        
                        NavigationLink {
                            NeedAttentionView(period: period)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(Color(red: 0.95, green: 0.40, blue: 0.42))
                }
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image("summary-icon")

                        Text(period == .daily ? "AI Summary of Today" : "AI Summary of This Week")
                            .font(.heading6)
                            .foregroundStyle(Color(red: 0.14, green: 0.15, blue: 0.22))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)

                        Spacer(minLength: 0)
                    }

                    Text(
                        period == .daily
                        ? "Today, your child spent 1 hour and 48 minutes on screen time, with most activity focused on educational content and a smaller portion on entertainment."
                        : "This week, your child spent a total of 12 hours and 45 minutes on screen time, with 68% dedicated to educational content and 32% to entertainment. Their digital activity showed a healthy balance between learning and relaxation throughout the week"
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
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            SummaryCardView(period: .daily, isNeedAttention: true)
            SummaryCardView(period: .weekly, isNeedAttention: false)
        }
        .padding()
    }
}
