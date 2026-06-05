//
//  SessionHistoryView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] All past sessions list

import SwiftUI

private enum HistoryLayout {
    static let horizontalPadding: CGFloat = 24
    static let cardCornerRadius: CGFloat = 26
    static let entryCornerRadius: CGFloat = 26
    static let entrySpacing: CGFloat = 22
}

// MARK: - View

struct SessionHistoryView: View {
    @Environment(\.sessionAnalysisStore) private var sessionAnalysisStore
    @Environment(\.profileViewModel) private var profileViewModel

    var body: some View {
        SessionHistoryScreen(
            sessionAnalysisStore: sessionAnalysisStore,
            profileViewModel: profileViewModel
        )
    }
}

private struct SessionHistoryScreen: View {
    @State private var viewModel: SessionHistoryViewModel
    private let profileViewModel: ProfileViewModel
    private let sessionAnalysisStore: SessionAnalysisStore?

    init(
        sessionAnalysisStore: SessionAnalysisStore?,
        profileViewModel: ProfileViewModel
    ) {
        self.sessionAnalysisStore = sessionAnalysisStore
        self.profileViewModel = profileViewModel
        _viewModel = State(
            initialValue: SessionHistoryViewModel(sessionAnalysisStore: sessionAnalysisStore)
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if !viewModel.monthOptions.isEmpty {
                    HStack {
                        Spacer()
                        monthFilterMenu
                    }
                }

                sessionContent
            }
            .padding(.horizontal, HistoryLayout.horizontalPadding)
            .padding(.vertical)
        }
        .background(.uiBackground)
        .foregroundStyle(.textPrimary)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.reload(for: profileViewModel.selectedChild)
                } label: {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primaryMediumBlue)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color(.systemGray6)))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                }
            }
        }
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

    private var sessionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if profileViewModel.selectedChild == nil {
                Text("Select a child profile to view session history.")
                    .font(.system(size: 14))
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.uiSurface)
                    .clipShape(RoundedRectangle(cornerRadius: HistoryLayout.cardCornerRadius))
            } else if sessionAnalysisStore == nil {
                Text("Session analysis storage is unavailable.")
                    .font(.system(size: 14))
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.uiSurface)
                    .clipShape(RoundedRectangle(cornerRadius: HistoryLayout.cardCornerRadius))
            } else if viewModel.sessionEntries.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.uiSurface)
                    .clipShape(RoundedRectangle(cornerRadius: HistoryLayout.cardCornerRadius))
            } else {
                SessionHistoryCard(entries: viewModel.sessionEntries)
            }
        }
    }

    private var emptyMessage: String {
        if viewModel.selectedMonth.isEmpty {
            return "No analyzed sessions yet. Complete a session with screen recording to see AI analysis here."
        }
        return "No session analysis for \(viewModel.selectedMonth)."
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

// MARK: - Session History Card

private struct SessionHistoryCard: View {
    let entries: [SessionHistoryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: HistoryLayout.entrySpacing) {
            ForEach(entries) { entry in
                NavigationLink {
                    SessionHistoryDetailView(entry: entry)
                } label: {
                    SessionHistoryRow(entry: entry)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SessionHistoryRow: View {
    let entry: SessionHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.dateLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.textPrimary)

                    Text(entry.timeLabel)
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = entry.errorMessage, entry.result == nil {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let category = entry.categoryLabel {
                Text(category)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primaryMediumBlue)
            }

            if let summary = entry.summaryPreview {
                Text(summary)
                    .font(.system(size: 14))
                    .foregroundStyle(.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if entry.screenCount > 0 {
                Text("\(entry.screenCount) screens analyzed")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: HistoryLayout.entryCornerRadius))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SessionHistoryView()
            .environment(\.profileViewModel, ProfileViewModel(childRepository: InMemoryChildRepository()))
    }
}
