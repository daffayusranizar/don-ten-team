//
//  WeeklySummaryView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P2] Full weekly report card

import SwiftUI

enum Period: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
}

struct WeeklySummaryView: View {
    @Environment(\.profileViewModel) private var profileViewModel
    @Environment(\.weeklySummaryViewModel) private var viewModel
    @State private var selectedPeriod: Period = .daily

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
                    SuggestionHistoryView()
                } label: {
                    Image(systemName: "clock")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primaryMediumBlue)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color(.systemGray6)))
                }
                .accessibilityLabel("Suggestion history")
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)

            if let viewModel {
                ReportView(
                    childId: profileViewModel.selectedChild?.id,
                    period: selectedPeriod,
                    report: viewModel.report,
                    emptyMessage: viewModel.emptyMessage,
                    isLoading: viewModel.isLoading,
                    isRefreshing: viewModel.isRefreshing,
                    suggestionTryResetGeneration: viewModel.suggestionTryResetGeneration,
                    onRegenerateWeekly: weeklyRegenerateAction(viewModel: viewModel)
                )
            } else {
                ReportView(
                    childId: nil,
                    period: selectedPeriod,
                    report: nil,
                    emptyMessage: "Insights are unavailable right now.",
                    isLoading: false,
                    isRefreshing: false,
                    onRegenerateWeekly: nil
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
    }

    private func refreshInsights() {
        guard let viewModel else { return }
        viewModel.selectedPeriod = selectedPeriod
        viewModel.refresh(
            childId: profileViewModel.selectedChild?.id,
            child: profileViewModel.selectedChild
        )
    }

    private func weeklyRegenerateAction(viewModel: WeeklySummaryViewModel) -> (() -> Void)? {
        #if DEBUG
        return {
            viewModel.refreshWeeklyGeneration(
                childId: profileViewModel.selectedChild?.id,
                child: profileViewModel.selectedChild
            )
        }
        #else
        return nil
        #endif
    }
}

struct ReportView: View {
    @Environment(\.sessionAnalysisStore) private var sessionAnalysisStore

    let childId: UUID?
    let period: Period
    let report: UsageInsightReport?
    let emptyMessage: String?
    let isLoading: Bool
    let isRefreshing: Bool
    var suggestionTryResetGeneration: UInt64 = 0
    var onRegenerateWeekly: (() -> Void)?
    @State private var isTrySuggestion = false
    @State private var savedTry: SavedSuggestionTry?
    @State private var showOfflineActivityLibrary = false

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                LazyVStack(spacing: 16) {
                    if isLoading {
                        ProgressView("Loading insights…")
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else if let report {
                        usageInsightCard(report: report)
                        aiSummaryCard(report: report)
                        if period == .weekly, let suggestion = report.weeklySuggestion, let childId, let weekKey = report.weekKey {
                            if isTrySuggestion {
                                SuggestionFlowView(
                                    childId: childId,
                                    weekKey: weekKey,
                                    suggestionText: suggestion,
                                    followUpOptions: report.followUpOptions,
                                    onComplete: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            isTrySuggestion = false
                                        }
                                        reloadSavedTry(childId: childId, weekKey: weekKey)
                                    }
                                )
                            } else if let savedTry {
                                weeklySuggestionSavedCard(savedTry: savedTry)
                            } else {
                                weeklySuggestionCard(suggestion: suggestion)
                            }
                        }
                        recommendedActivityCard(report: report)
                    } else if let emptyMessage {
                        insightEmptyState(message: emptyMessage)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 96)
                .opacity(isRefreshing ? 0.45 : 1)
                .allowsHitTesting(!isRefreshing)

                if isRefreshing {
                    VStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.large)
                        Text(regeneratingMessage)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .navigationDestination(isPresented: $showOfflineActivityLibrary) {
            OfflineActivityView()
        }
        .onAppear {
            reloadSavedTryIfNeeded()
        }
        .onChange(of: childId) { _, _ in
            reloadSavedTryIfNeeded()
        }
        .onChange(of: report?.weekKey) { _, _ in
            reloadSavedTryIfNeeded()
        }
        .onChange(of: report?.aiSummaryShort) { _, _ in
            isTrySuggestion = false
            reloadSavedTryIfNeeded()
        }
        .onChange(of: report?.aiSummaryDetail) { _, _ in
            isTrySuggestion = false
            reloadSavedTryIfNeeded()
        }
        .onChange(of: report?.weeklySuggestion) { _, _ in
            isTrySuggestion = false
            reloadSavedTryIfNeeded()
        }
        .onChange(of: report?.followUpOptions) { _, _ in
            isTrySuggestion = false
            reloadSavedTryIfNeeded()
        }
        .onChange(of: suggestionTryResetGeneration) { _, _ in
            resetWeeklyTryUIState()
            reloadSavedTryIfNeeded()
        }
    }

    private func resetWeeklyTryUIState() {
        isTrySuggestion = false
        savedTry = nil
    }

    private func regenerateWeekly() {
        resetWeeklyTryUIState()
        onRegenerateWeekly?()
    }

    private var regeneratingMessage: String {
        period == .weekly ? "Regenerating weekly insight…" : "Refreshing insight…"
    }

    private func reloadSavedTryIfNeeded() {
        guard let childId, let weekKey = report?.weekKey else {
            savedTry = nil
            return
        }
        reloadSavedTry(childId: childId, weekKey: weekKey)
    }

    private func reloadSavedTry(childId: UUID, weekKey: String) {
        savedTry = sessionAnalysisStore?.fetchSuggestionTry(childId: childId, weekKey: weekKey)
    }

    private func usageInsightCard(report: UsageInsightReport) -> some View {
        InsightCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image("insight-icon")

                    Text(period == .daily ? "Today's Usage Insight" : "This Week Usage Insight")
                        .font(.heading6)

                    Spacer(minLength: 0)
                }

                Text(report.dateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if report.chartItems.isEmpty {
                    Text("Category breakdown appears after a recorded session is analyzed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    CategoryBreakdownList(items: report.chartItems)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
    }

    private func aiSummaryCard(report: UsageInsightReport) -> some View {
        InsightCard {
            VStack(spacing: 0) {
                if report.needsAttention {
                    NavigationLink {
                        NeedAttentionView(period: period)
                    } label: {
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
                    .buttonStyle(.plain)
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

                        #if DEBUG
                        if period == .weekly, onRegenerateWeekly != nil {
                            Button(action: regenerateWeekly) {
                                if isRefreshing {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Label("Regenerate all", systemImage: "arrow.clockwise")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.orange)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(isRefreshing)
                            .accessibilityLabel("Regenerate weekly summary and suggestion")
                        }
                        #endif
                    }

                    Text(InsightSummaryFormatting.plainTextForCard(report.aiSummaryShort))
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.24))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    if report.aiSummaryDetail != report.aiSummaryShort {
                        NavigationLink {
                            InsightSummaryDetailView(
                                title: period == .daily ? "AI Summary of Today" : "AI Summary of This Week",
                                detailText: report.aiSummaryDetail
                            )
                        } label: {
                            Text("See detail")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primaryMediumBlue)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
        }
    }

    private func weeklySuggestionCard(suggestion: String) -> some View {
        InsightCard {
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

                    #if DEBUG
                    if onRegenerateWeekly != nil {
                        Button(action: regenerateWeekly) {
                            if isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isRefreshing)
                        .accessibilityLabel("Regenerate weekly summary and suggestion")
                    }
                    #endif
                }

                Text(suggestion)
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
            .background(Color("primaryMediumBlue").opacity(0.2))
        }
    }

    private func weeklySuggestionSavedCard(savedTry: SavedSuggestionTry) -> some View {
        InsightCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image("suggestion-icon")

                    Text("This Week Suggestion")
                        .font(.heading6)
                        .foregroundStyle(Color(red: 0.14, green: 0.15, blue: 0.22))

                    Spacer(minLength: 0)

                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }

                Text(savedTry.suggestion)
                    .font(.bodyRegular)
                    .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.24))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                if savedTry.tried, let selection = savedTry.followUpSelection, !selection.isEmpty {
                    Text("Response: \(selection)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primaryMediumBlue)
                } else if !savedTry.tried {
                    Text("You chose not to try this suggestion.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                if let note = savedTry.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 14))
                        .foregroundStyle(.textSecondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                NavigationLink {
                    SuggestionHistoryView()
                } label: {
                    Text("View suggestion history")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primaryMediumBlue)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 16)
            .background(Color("primaryMediumBlue").opacity(0.2))
        }
    }

    private func recommendedActivityCard(report: UsageInsightReport) -> some View {
        InsightCard {
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
                    action: {
                        showOfflineActivityLibrary = true
                    }
                )
                .padding(.top, 10)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
    }

    private func insightEmptyState(message: String) -> some View {
        InsightCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(period == .daily ? "Today's Usage Insight" : "This Week Usage Insight")
                    .font(.heading6)
                Text(message)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
    }
}

private struct InsightCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(red: 0.82, green: 0.83, blue: 0.88), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
}

private struct CategoryBreakdownList: View {
    let items: [UsageChartItem]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(items) { item in
                HStack(spacing: 10) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 10, height: 10)
                    Text(item.name)
                        .font(.subheadline)
                    Spacer(minLength: 8)
                    Text("\(Int(item.value))%")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct InsightSummaryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let detailText: String

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            InsightFormattedText(text: detailText)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
        }
        .background(Color(red: 0.97, green: 0.97, blue: 0.98))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Preview Helpers

private extension UsageInsightReport {
    static let previewDaily = UsageInsightReport(
        dateLabel: "8 June 2026",
        weekKey: nil,
        chartItems: [
            UsageChartItem(name: "Entertainment", value: 45, color: .orange),
            UsageChartItem(name: "Education",     value: 35, color: .blue),
            UsageChartItem(name: "Games",         value: 20, color: .green)
        ],
        aiSummaryShort: "Today, your child spent 1 hour and 48 minutes on screen time. Most activity was educational, with a smaller portion on entertainment.",
        aiSummaryDetail: """
        Overall, your child spent 1 hour and 48 minutes on screen time today. Most activity was focused on educational content, with a smaller portion on entertainment. Screen time was well within the recommended limit.
        Topics that are repeated most often are: educational videos, light entertainment
        What Appears To Hold Attention: Your child appears drawn to short educational clips and occasionally switches to entertainment content.
        The evidencce of this report are: repeated educational topics across sessions, balanced category mix, no risky themes detected
        Overall, looking at the evidence, we recommend that you to do this: ask what they learned from one video tonight.
        """,
        offlineActivityTeaser: "Try a 15-minute outdoor drawing session with your child today!",
        offlineActivity: "Take your child outside and spend 15 minutes drawing or painting together. Ask them to draw something they learned from the screen today — it reinforces learning and builds creativity.",
        needsAttention: false,
        weeklySuggestion: nil,
        followUpOptions: []
    )

    static let previewWeekly = UsageInsightReport(
        dateLabel: "2 June 2026 – 8 June 2026",
        weekKey: "2026-W23",
        chartItems: [
            UsageChartItem(name: "Entertainment", value: 55, color: .orange),
            UsageChartItem(name: "Education",     value: 28, color: .blue),
            UsageChartItem(name: "Games",         value: 17, color: .green)
        ],
        aiSummaryShort: "This week, your child spent 12 hours and 45 minutes on screen — mostly entertainment (55%) and education (28%).",
        aiSummaryDetail: """
        This week, your child spent a total of 12 hours and 45 minutes on screen time, with 55% on entertainment and 28% on educational content. Entertainment usage increased compared to earlier in the week.
        Topics that are repeated most often are: short-form entertainment, educational explainers
        What Appears To Hold Attention: Your child appears frequently drawn to fast-paced entertainment clips and educational explainers.
        The evidence of this report are: entertainment dominated total time, educational content appeared in most sessions, no major concerns detected
        Overall, looking at the evidence, we recommend that you: balance one educational watch with a short offline activity mid-week.
        """,
        offlineActivityTeaser: "Try a 20-minute board game session to balance screen time!",
        offlineActivity: "Spend 20 minutes playing a board game together as a family. This encourages strategic thinking, social skills, and gives your child a healthy break from screens.",
        needsAttention: true,
        weeklySuggestion: "Watch one short educational video together tonight and ask your child what they found most interesting. This small habit builds critical thinking and strengthens your bond.",
        followUpOptions: WeeklyInsightOutput.defaultFollowUpOptions
    )
}

// Full-screen preview wrapper — mirrors WeeklySummaryView layout without real environment objects
private struct WeeklySummaryPreview: View {
    @State private var selectedPeriod: Period = .daily

    private var currentReport: UsageInsightReport {
        selectedPeriod == .daily ? .previewDaily : .previewWeekly
    }

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(Period.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)

            ReportView(
                childId: UUID(),
                period: selectedPeriod,
                report: currentReport,
                emptyMessage: nil,
                isLoading: false,
                isRefreshing: false,
                onRegenerateWeekly: nil
            )

            Spacer()
        }
        .navigationTitle("Usage Insight")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                } label: {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                }

            }
        }
    }
}

#Preview("Full Screen") {
    NavigationStack {
        WeeklySummaryPreview()
    }
}

#Preview("Empty State") {
    NavigationStack {
        VStack {
            Picker("Period", selection: .constant(Period.daily)) {
                ForEach(Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 4)

            ReportView(
                childId: nil,
                period: .daily,
                report: nil,
                emptyMessage: "No analyzed sessions today yet. Complete a session with screen recording to see today's usage insight.",
                isLoading: false,
                isRefreshing: false,
                onRegenerateWeekly: nil
            )
            Spacer()
        }
        .navigationTitle("Usage Insight")
        .toolbarTitleDisplayMode(.inline)
    }
}

#Preview("Loading") {
    NavigationStack {
        VStack {
            Picker("Period", selection: .constant(Period.daily)) {
                ForEach(Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 4)

            ReportView(
                childId: nil,
                period: .daily,
                report: nil,
                emptyMessage: nil,
                isLoading: true,
                isRefreshing: false,
                onRegenerateWeekly: nil
            )
            Spacer()
        }
        .navigationTitle("Usage Insight")
        .toolbarTitleDisplayMode(.inline)
    }
}



