//
//  ProfileAvatarView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] Child emoji/initial avatar

import SwiftUI

struct ProfileAvatarView: View {
    let child: Child
    var size: CGFloat = 60

    private var initial: String {
        String(child.name.prefix(1)).uppercased()
    }

    var body: some View {
        Group {
            if let avatar = child.avatarImage {
                avatar.image
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(.primaryMediumBlue)
                    .overlay {
                        Text(initial)
                            .font(.system(size: size * 0.4, weight: .semibold))
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

#Preview {
    ProfileAvatarView(
        child: Child(
            name: "Raka",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -8, to: Date()) ?? Date(),
            gender: .boy,
            avatarAssetName: ImageAsset.childAvatar1.rawValue
        ),
        size: 80
    )
}
