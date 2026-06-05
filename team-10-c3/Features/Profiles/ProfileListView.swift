//
//  ProfileListView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] Grid of all child profiles

import SwiftUI

struct ProfileListView: View {
    @Environment(\.profileViewModel) private var profileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddChild = false
    @State private var selectedChild: Child?
    @State private var showDetail = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .padding()
                        .background(
                            Circle()
                                .fill(.uiSurface)
                        )
                }

                Spacer()

                Text("Children")
                    .font(.system(size: 25, weight: .bold))

                Spacer()

                Button {
                    showAddChild = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .padding()
                        .background(
                            Circle()
                                .fill(.uiSurface)
                        )
                }
            }

            if profileViewModel.children.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(profileViewModel.children) { child in
                            Button {
                                selectedChild = child
                                showDetail = true
                            } label: {
                                ProfileListCard(child: child)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .padding(.horizontal, 30)
        .padding(.vertical)
        .foregroundStyle(.textPrimary)
        .childProfileFormSheet(isPresented: $showAddChild) { child in
            profileViewModel.handleChildSaved(child)
        }
        .navigationDestination(isPresented: $showDetail) {
            if let selectedChild {
                ProfileDetailView(child: selectedChild)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.2.fill")
                .font(.system(size: 48))
                .foregroundStyle(.primaryMediumBlue)

            Text("No children yet")
                .font(.system(size: 22, weight: .semibold))

            Text("Add your first child profile to start tracking screen time.")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            PrimaryButton(
                title: "Add Child",
                size: .medium,
                systemImage: "plus",
                action: { showAddChild = true }
            )
            .padding(.top, 8)

            Spacer()
        }
    }
}

private struct ProfileListCard: View {
    let child: Child

    private var genderLabel: String {
        switch child.gender {
        case .boy: return "Male"
        case .girl: return "Female"
        case .preferNotToSay: return "Prefer not to say"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ProfileAvatarView(child: child, size: 72)

            Text(child.name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.textPrimary)

            Text("Age \(child.currentAge) | \(genderLabel)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(.uiBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        ProfileListView()
            .environment(\.profileViewModel, {
                let repository = InMemoryChildRepository()
                let viewModel = ProfileViewModel(childRepository: repository)
                try? repository.save(
                    Child(
                        name: "Raka",
                        dateOfBirth: Calendar.current.date(byAdding: .year, value: -8, to: Date()) ?? Date(),
                        gender: .boy
                    )
                )
                viewModel.loadChildren()
                return viewModel
            }())
    }
}
