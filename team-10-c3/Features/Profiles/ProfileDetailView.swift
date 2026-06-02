//
//  ProfileDetailView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] One child: sessions + usage

import SwiftUI

struct ProfileDetailView: View {
    let child: Child
    @Environment(\.dismiss) private var dismiss

    private var genderLabel: String {
        switch child.gender {
        case .boy: return "Male"
        case .girl: return "Female"
        case .preferNotToSay: return "Prefer not to say"
        }
    }

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
            }

            ProfileAvatarView(child: child, size: 120)

            VStack(spacing: 8) {
                Text(child.name)
                    .font(.system(size: 30, weight: .medium))

                Text("Age \(child.currentAge) | \(genderLabel)")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text("Session history coming soon.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 12)

            Spacer()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .padding(.horizontal, 30)
        .padding(.vertical)
        .foregroundStyle(.textPrimary)
    }
}

#Preview {
    NavigationStack {
        ProfileDetailView(
            child: Child(
                name: "Raka",
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -8, to: Date()) ?? Date(),
                gender: .boy
            )
        )
    }
}
