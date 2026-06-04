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

struct WeeklySummaryView: View {
    @State private var selectedPeriod: Period = .daily

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(Period.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                ReportView(period: selectedPeriod)

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

                        StackedBarCard(items: [
                            .init(name: "Entertainment", value: 45, color: .orange),
                            .init(name: "Games", value: 15, color: .green),
                            .init(name: "Education", value: 25, color: .blue)
                        ])
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 16)
                }

                CardView(width: 364, height: 242) {
                    VStack(spacing: 0) {
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

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(Color(red: 0.95, green: 0.40, blue: 0.42))

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
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.24))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .padding(.bottom, 20)
                    }
                }
                
                if period == .weekly {
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
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.24))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            
                            HStack {
                                PrimaryButton(
                                    title: "Not Now",
                                    size: .medium,
                                    systemImage: "",
                                    action: {}
                                )
                                .padding(.top, 8)
                    
                                PrimaryButton(
                                    title: "Try",
                                    size: .medium,
                                    systemImage: "",
                                    action: {}
                                )
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .padding(.bottom, 16)
                        .background(
                            Color("primaryMediumBlue").opacity(0.2)
                        )
                        
                    }
                }
                
                CardView(width: 364, height: 216) {
                    VStack {
                        HStack(spacing: 8) {
                            Image("activity-icon")

                            Text(period == .daily ? "AI Summary of Today" : "AI Summary of This Week")
                                .font(.heading6)
                                .foregroundStyle(Color(red: 0.14, green: 0.15, blue: 0.22))
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)

                            Spacer(minLength: 0)
                        }
                        
                        Text(
                            "Explore the recommended offline activity that we already provide for you to do it with your child!"
                        )
                        .font(.system(size: 17, weight: .regular))
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

struct CardView<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    let content: Content

    init(
        width: CGFloat,
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.width = width
        self.height = height
        self.content = content()
    }

    var body: some View {
        content
            .frame(minWidth: width, minHeight: height, alignment: .top)
            
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(red: 0.82, green: 0.83, blue: 0.88), lineWidth: 1)
            )
            .fixedSize(horizontal: false, vertical: true)
            .shadow(radius: 6)
    }
}

struct CategoryItem: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let color: Color
}

struct StackedBarCard: View {
    let items: [CategoryItem]

    private var total: Double {
        items.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GeometryReader { geo in
                let total = items.reduce(0) { $0 + $1.value }

                ZStack(alignment: .leading) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let consumed = items.prefix(index).reduce(0) { $0 + $1.value }
                        let remainingWidth = geo.size.width * ((total - consumed) / total)

                        Capsule()
                            .fill(item.color)
                            .frame(width: remainingWidth, height: 24)
                            .shadow(radius: 2)
                    }
                }
            }
            .frame(height: 24)

            VStack(spacing: 10) {
                ForEach(items) { item in
                    HStack {
                        Circle()
                            .fill(item.color)
                            .frame(width: 10, height: 10)

                        Text(item.name)
                            .font(.caption)

                        Spacer()

                        Text("\(Int(item.value))%")
                            .font(.caption)
                            .foregroundStyle(item.color)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WeeklySummaryView()
    }
}
