//
//  SuggestionHistoryView.swift
//  team-10-c3
//

import SwiftUI

struct SuggestionHistoryView: View {
    @Environment(\.suggestionHistoryRepository) private var repository
    @Environment(\.profileViewModel) private var profileViewModel
    @State private var viewModel: SuggestionHistoryViewModel?

    var body: some View {
        Group {
            if let viewModel {
                SuggestionHistoryScreen(
                    viewModel: viewModel,
                    profileViewModel: profileViewModel
                )
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = SuggestionHistoryViewModel(repository: repository)
            }
            viewModel?.reload(for: profileViewModel.selectedChild)
        }
        .onChange(of: profileViewModel.selectedChild?.id) { _, _ in
            viewModel?.reload(for: profileViewModel.selectedChild)
        }
    }
}

private struct SuggestionHistoryScreen: View {
    @Bindable var viewModel: SuggestionHistoryViewModel
    let profileViewModel: ProfileViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if !viewModel.monthOptions.isEmpty {
                    HStack {
                        Spacer()
                        monthFilterMenu
                    }
                }

                historyContent
            }
            .padding(.horizontal, 24)
            .padding(.vertical)
        }
        .background(.uiBackground)
        .foregroundStyle(.textPrimary)
        .navigationTitle("Suggestion History")
        .navigationBarTitleDisplayMode(.inline)
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

    @ViewBuilder
    private var historyContent: some View {
        if profileViewModel.selectedChild == nil {
            emptyCard("Select a child profile to view suggestion history.")
        } else if viewModel.entries.isEmpty {
            emptyCard(emptyMessage)
        } else {
            VStack(spacing: 16) {
                ForEach(viewModel.entries) { entry in
                    SuggestionHistoryRow(entry: entry)
                }
            }
        }
    }

    private var emptyMessage: String {
        if viewModel.selectedMonth.isEmpty {
            return "No saved suggestions yet. Try a weekly suggestion and save your notes."
        }
        return "No saved suggestions for \(viewModel.selectedMonth)."
    }

    private func emptyCard(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: 26))
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

private struct SuggestionHistoryRow: View {
    let entry: SuggestionHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(entry.dateLabel)
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Text(entry.tried ? "Tried" : "Skipped")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entry.tried ? .primaryMediumBlue : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(entry.tried
                                ? Color.primaryMediumBlue.opacity(0.12)
                                : Color(.systemGray5))
                    )
            }

            Text(entry.suggestion)
                .font(.system(size: 15))
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if entry.tried, let selection = entry.followUpSelection, !selection.isEmpty {
                Label(selection, systemImage: "bubble.left.and.bubble.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.textSecondary)
            }

            if !entry.note.isEmpty {
                Text(entry.note)
                    .font(.system(size: 14))
                    .foregroundStyle(.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(18)
        .background(.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SuggestionHistoryView()
            .environment(\.suggestionHistoryRepository, InMemorySuggestionHistoryRepository.preview)
    }
}
#endif
