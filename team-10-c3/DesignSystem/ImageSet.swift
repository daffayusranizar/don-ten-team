//
//  ImageSet.swift
//  team-10-c3
//
//  Typed accessors for Assets.xcassets image sets.

import SwiftUI

public enum ImageAsset: String {
    case childAvatar1 = "ChildAvatar1"
    case childAvatar2 = "ChildAvatar2"
    case childAvatar3 = "ChildAvatar3"
    case childAvatar4 = "ChildAvatar4"
    case childAvatar5 = "ChildAvatar5"
    case childAvatar6 = "ChildAvatar6"
    case childAvatar7 = "ChildAvatar7"
    case childAvatar8 = "ChildAvatar8"
    case childAvatar9 = "ChildAvatar9"
    case parentProfileAvatar = "ParentProfileAvatar"
    case instagram = "Instagram"
    case tiktok = "TikTok"
    case youtube = "YouTube"
}

public enum ChildAvatarImage: CaseIterable, Identifiable, Equatable {
    case avatar1
    case avatar2
    case avatar3
    case avatar4
    case avatar5
    case avatar6
    case avatar7
    case avatar8
    case avatar9

    public var id: ImageAsset { asset }

    public var asset: ImageAsset {
        switch self {
        case .avatar1: .childAvatar1
        case .avatar2: .childAvatar2
        case .avatar3: .childAvatar3
        case .avatar4: .childAvatar4
        case .avatar5: .childAvatar5
        case .avatar6: .childAvatar6
        case .avatar7: .childAvatar7
        case .avatar8: .childAvatar8
        case .avatar9: .childAvatar9
        }
    }

    public init?(asset: ImageAsset) {
        switch asset {
        case .childAvatar1: self = .avatar1
        case .childAvatar2: self = .avatar2
        case .childAvatar3: self = .avatar3
        case .childAvatar4: self = .avatar4
        case .childAvatar5: self = .avatar5
        case .childAvatar6: self = .avatar6
        case .childAvatar7: self = .avatar7
        case .childAvatar8: self = .avatar8
        case .childAvatar9: self = .avatar9
        default: return nil
        }
    }

    public var image: Image {
        asset.image
    }
}

extension ImageAsset {
    public var image: Image {
        Image(rawValue)
    }

    public init?(storedName: String) {
        self.init(rawValue: storedName)
    }
}

struct ChildAvatarOption: View {
    let avatar: ChildAvatarImage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            avatar.image
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(.primaryMediumBlue, lineWidth: isSelected ? 3 : 0)
                }
        }
        .buttonStyle(.plain)
    }
}
