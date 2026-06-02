//
//  SessionHistoryView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] All past sessions list

import SwiftUI

private enum HistoryLayout {
    static let horizontalPadding: CGFloat = 30
    static let cardCornerRadius: CGFloat = 26
    static let entryCornerRadius: CGFloat = 26
    static let entrySpacing: CGFloat = 22
}

// MARK: - View

struct SessionHistoryView: View {
    @Environment(\.suggestionHistoryRepository) private var suggestionHistoryRepository
    @Environment(\.sessionRepository) private var sessionRepository
    @Environment(\.profileViewModel) private var profileViewModel

    var body: some View {
        SessionHistoryScreen(
            suggestionHistoryRepository: suggestionHistoryRepository,
            sessionRepository: sessionRepository,
            profileViewModel: profileViewModel
        )
    }
}

private struct SessionHistoryScreen: View {
    @State private var viewModel: SessionHistoryViewModel
    private let profileViewModel: ProfileViewModel

    init(
        suggestionHistoryRepository: SuggestionHistoryRepository,
        sessionRepository: SessionRepository,
        profileViewModel: ProfileViewModel
    ) {
        self.profileViewModel = profileViewModel
        _viewModel = State(
            initialValue: SessionHistoryViewModel(
                suggestionHistoryRepository: suggestionHistoryRepository,
                sessionRepository: sessionRepository
            )
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                historySegmentedControl

                HStack {
                    Spacer()
                    monthFilterMenu
                }

                if viewModel.selectedTab == .suggestion {
                    suggestionContent
                } else {
                    screenTimeContent
                }
            }
            .padding(.horizontal, HistoryLayout.horizontalPadding)
            .padding(.vertical)
        }
        .background(.uiBackground)
        .foregroundStyle(.textPrimary)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.reload(for: profileViewModel.selectedChild)
        }
        .onChange(of: profileViewModel.selectedChild?.id) { _, _ in
            viewModel.reload(for: profileViewModel.selectedChild)
        }
        .alert("Could Not Load History", isPresented: loadErrorPresented) {
            Button("OK", role: .cancel) {
                viewModel.loadError = nil
            }
        } message: {
            Text(viewModel.loadError ?? "")
        }
    }

    private var historySegmentedControl: some View {
        Picker("History filter", selection: $viewModel.selectedTab) {
            ForEach(HistoryTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    private var monthFilterMenu: some View {
        Menu {
            ForEach(viewModel.monthOptions, id: \.self) { month in
                Button {
                    viewModel.selectMonth(month)
                } label: {
                    if month == viewModel.selectedMonth {
                        Label(month, systemImage: "checkmark")
                    } else {
                        Text(month)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(viewModel.selectedMonth)
                    .font(.system(size: 11, weight: .semibold))

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(red: 0.95, green: 0.95, blue: 0.95))
            )
        }
    }

    private var suggestionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.selectedMonth)
                .font(.heading6)
                .foregroundStyle(.textPrimary)

            if viewModel.suggestionEntries.isEmpty {
                Text("No suggestion history for \(viewModel.selectedMonth).")
                    .font(.system(size: 14))
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.uiSurface)
                    .clipShape(RoundedRectangle(cornerRadius: HistoryLayout.cardCornerRadius))
            } else {
                SuggestionHistoryCard(entries: viewModel.suggestionEntries)
            }
        }
    }

    private var screenTimeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.selectedMonth)
                .font(.heading6)
                .foregroundStyle(.textPrimary)

            if viewModel.screenTimeEntries.isEmpty {
                Text("No screen time sessions for \(viewModel.selectedMonth).")
                    .font(.system(size: 14))
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.uiSurface)
                    .clipShape(RoundedRectangle(cornerRadius: HistoryLayout.cardCornerRadius))
            } else {
                ScreenTimeHistoryCard(entries: viewModel.screenTimeEntries)
            }
        }
    }

    private var loadErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.loadError != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.loadError = nil
                }
            }
        )
    }
}

// MARK: - Screen Time History Card

private struct ScreenTimeHistoryCard: View {
    let entries: [ScreenTimeHistoryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: HistoryLayout.entrySpacing) {
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.dateLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.textPrimary)

                    Text("\(entry.durationLabel) total · Top app: \(entry.topAppName)")
                        .font(.system(size: 14))
                        .foregroundStyle(.textSecondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.uiSurface)
                .clipShape(RoundedRectangle(cornerRadius: HistoryLayout.entryCornerRadius))
            }
        }
    }
}

// MARK: - Suggestion History Card

private struct SuggestionHistoryCard: View {
    let entries: [SuggestionHistoryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: HistoryLayout.entrySpacing) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.dateLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    SuggestionHistoryEntryRow(entry: entry, index: index)
                }
                .padding(.top, index == 0 ? 0 : 4)
            }
        }
        .padding(.horizontal, 21)
        .padding(.vertical, 35)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.primaryDarkBlue)
        .clipShape(RoundedRectangle(cornerRadius: HistoryLayout.cardCornerRadius))
    }
}

private struct SuggestionHistoryEntryRow: View {
    let entry: SuggestionHistoryEntry
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("“\(entry.suggestion)”")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(entry.detail)
                .font(.system(size: 12))
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            SuggestionOutcomePill(label: entry.outcome, index: index)
                .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: HistoryLayout.entryCornerRadius))
    }
}

private struct SuggestionOutcomePill: View {
    let label: String
    let index: Int

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(OutcomePillColor.color(for: index))
            .clipShape(Capsule())
    }
}

private enum OutcomePillColor {
    static let palette: [Color] = [
        .decorativeCoralPink,
        .decorativeLavender,
        .decorativeSkyBlue,
        .decorativeSoftOrange,
        .decorativeMintGreen,
        .decorativeSunnyYellow,
        .primarySoftPurple,
        .primaryTeal,
        .primaryMediumBlue,
        .usageGames,
        .usageEducation,
        .usageEntertainment,
        .statusDanger,
        .statusWarning,
        .statusInfo,
        .statusSuccess,
    ]

    static func color(for index: Int) -> Color {
        let hash = abs(index &* 2654435761)
        return palette[hash % palette.count]
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SessionHistoryView()
            .environment(\.suggestionHistoryRepository, InMemorySuggestionHistoryRepository.preview)
            .environment(\.sessionRepository, InMemorySessionRepository())
            .environment(\.profileViewModel, ProfileViewModel(childRepository: InMemoryChildRepository()))
    }
}
