//
//  WeeklySummaryView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P2] Full weekly report card

import SwiftUI
import Charts

enum Period: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
}

let options = [
    "Opened up and talked",
    "Enjoy it, not much talking",
    "Led to a longer conversation",
    "Didn't want to"
]

struct CategoryItem: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let color: Color
}

struct WeeklySummaryView: View {
    @State private var selectedPeriod: Period = .daily
    @State private var dataExist: Bool = true

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(Period.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 18)

                if dataExist {
                    ReportView(period: selectedPeriod)
                } else {
                    Spacer()
                    
                    ContentUnavailableView {
                        Label {
                            Text("No Data Yet")
                        } icon: {
                            Image("empty-state")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                                .scaleEffect(3)
                        }
                    } description: {
                        Text("Check back later once your child has started using their device.")
                    }
                }

                Spacer()
            }
            .navigationTitle("Insight Usage")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // your action here
                    } label: {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    }
                }
            }
        }
    }
}

struct ReportView: View {
    let period: Period
    @State private var isTrySuggestion: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                
                
                
                CardView(width: 364, height: 216) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image("insight-icon")

                            Text(period == .daily ? "Today's Usage Insight" : "This Week Usage Insight")
                                .font(.heading6)

                            Spacer()
                        }

                        Text("10 June 2026")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        StackedBarChartView(items: [
                            .init(name: "Entertainment", value: 45, color: .orange),
                            .init(name: "Games", value: 15, color: .green),
                            .init(name: "Education", value: 25, color: .blue)
                        ])
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 16)
                }

                SummaryCardView(period: period, isNeedAttention: true)
                
                
                if period == .weekly {
                    if isTrySuggestion {
                        SuggestionFlowView()
                    } else {
                        CardView(width: 364, height: 216) {
                            VStack {
                                HStack(spacing: 8) {
                                    Image("suggestion-icon")

                                    Text("This Week Suggestion")
                                        .font(.heading6)
                                        .foregroundStyle(Color(red: 0.14, green: 0.15, blue: 0.22))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.9)
                                        .padding(8)

                                    Spacer(minLength: 0)
                                }
                                Text(
                                    "Spend 15–20 minutes talking with your child about what they watched this week — ask what they learned, which content made them happy, and if anything confused or surprised them. These small conversations can help parents better understand their child’s interests while encouraging healthier and more mindful screen habits."
                                )
                                .font(.bodyRegular)
                                .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.24))
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                                
                               
                                PrimaryButton(
                                    title: "Try",
                                    size: .medium,
                                    systemImage: "",
                                    action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            isTrySuggestion.toggle()
                                        }
                                    }
                                )
                                .padding(.top, 8)
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 14)
                            .padding(.bottom, 16)
                            .background(
                                Color("primaryMediumBlue").opacity(0.2)
                            )
                            
                        }
                    }
                    
                }
                
                CardView(width: 364, height: 216) {
                    VStack {
                        HStack(spacing: 8) {
                            Image("activity-icon")

                            Text(period == .daily ? "Recommended Activity" : "Recommended Activity")
                                .font(.heading6)
                                .foregroundStyle(Color(red: 0.14, green: 0.15, blue: 0.22))
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)

                            Spacer(minLength: 0)
                        }
                        
                        Text(
                            "Explore the recommended offline activity that we already provide for you to do it with your child!"
                        )
                        .font(.bodyRegular)
                        .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.24))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                        
                        PrimaryButton(
                            title: "See Activity",
                            size: .medium,
                            systemImage: "",
                            action: {}
                        )
                        .padding(.top, 8)
                        
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    NavigationStack {
        WeeklySummaryView()
    }
}
