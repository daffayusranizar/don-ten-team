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
    @Environment(\.profileViewModel) private var profileViewModel
    @Environment(\.weeklySummaryViewModel) private var viewModel
    @State private var selectedPeriod: Period = .daily
    @State private var showOfflineActivity = false

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(Period.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                NavigationLink {
                    SessionHistoryView()
                } label: {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primaryMediumBlue)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color(.systemGray6)))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)

            if let viewModel {
                ReportView(
                    period: selectedPeriod,
                    report: viewModel.report,
                    emptyMessage: viewModel.emptyMessage,
                    isLoading: viewModel.isLoading,
                    showOfflineActivity: $showOfflineActivity
                )
            } else {
                ReportView(
                    period: selectedPeriod,
                    report: nil,
                    emptyMessage: "Insights are unavailable right now.",
                    isLoading: false,
                    showOfflineActivity: $showOfflineActivity
                )
            }

            Spacer()
        }
        .navigationTitle("Usage Insight")
        .toolbarTitleDisplayMode(.inline)
        .onAppear {
            refreshInsights()
        }
        .onChange(of: selectedPeriod) { _, newValue in
            viewModel?.selectedPeriod = newValue
            refreshInsights()
        }
        .onChange(of: profileViewModel.selectedChild?.id) { _, _ in
            refreshInsights()
        }
        .navigationDestination(isPresented: $showOfflineActivity) {
            if let activity = viewModel?.report?.offlineActivity {
                InsightOfflineActivityDetailView(activityText: activity)
            }
        }
    }

    private func refreshInsights() {
        guard let viewModel else { return }
        viewModel.selectedPeriod = selectedPeriod
        viewModel.refresh(
            childId: profileViewModel.selectedChild?.id,
            child: profileViewModel.selectedChild
        )
    }
}

struct ReportView: View {
    let period: Period
    let report: UsageInsightReport?
    let emptyMessage: String?
    let isLoading: Bool
    @Binding var showOfflineActivity: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if isLoading {
                    ProgressView("Loading insights…")
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if let report {
                    usageInsightCard(report: report)
                    aiSummaryCard(report: report)
                    recommendedActivityCard(report: report)
                } else if let emptyMessage {
                    insightEmptyState(message: emptyMessage)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
    }

    private func usageInsightCard(report: UsageInsightReport) -> some View {
        CardView(minHeight: 216) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image("insight-icon")

                    Text(period == .daily ? "Today's Usage Insight" : "This Week Usage Insight")
                        .font(.heading6)

                    Spacer()
                }

                Text(report.dateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if report.chartItems.isEmpty {
                    Text("Chart data will appear after a recorded session is analyzed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    StackedBarCard(items: report.chartItems)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
    }

    private func aiSummaryCard(report: UsageInsightReport) -> some View {
        CardView(minHeight: 242) {
            VStack(spacing: 0) {
                if report.needsAttention {
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
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image("summary-icon")

                        Text("AI Summary of This Week")
                            .font(.heading6)
                            .foregroundStyle(Color(red: 0.14, green: 0.15, blue: 0.22))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)

                        Spacer(minLength: 0)
                    }

                    Text(report.aiSummary)
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
    }

    private func recommendedActivityCard(report: UsageInsightReport) -> some View {
        CardView(minHeight: 190) {
            VStack {
                HStack(spacing: 8) {
                    Image("activity-icon")

                    Text("Recommended Activity")
                        .font(.heading6)
                        .foregroundStyle(Color(red: 0.14, green: 0.15, blue: 0.22))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Spacer(minLength: 0)
                }

                Text(report.offlineActivityTeaser)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.24))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                PrimaryButton(
                    title: "See Activity",
                    size: .medium,
                    systemImage: "",
                    action: { showOfflineActivity = true }
                )
                .padding(.top, 10)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
    }

    private func insightEmptyState(message: String) -> some View {
        CardView(minHeight: 180) {
            VStack(alignment: .leading, spacing: 12) {
                Text(period == .daily ? "Today's Usage Insight" : "This Week Usage Insight")
                    .font(.heading6)
                Text(message)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
        }
    }
}

struct InsightOfflineActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let activityText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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
                Spacer()
                Color.clear.frame(width: 56, height: 56)
            }

            Text(activityText)
                .font(.system(size: 18))
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .background(.uiBackground)
        .navigationBarBackButtonHidden(true)
    }
}

struct CardView<Content: View>: View {
    let minHeight: CGFloat
    let content: Content

    init(
        minHeight: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.minHeight = minHeight
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(red: 0.82, green: 0.83, blue: 0.88), lineWidth: 1)
            )
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
}

struct StackedBarCard: View {
    let items: [UsageChartItem]

    private var total: Double {
        max(items.reduce(0) { $0 + $1.value }, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GeometryReader { geo in
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
