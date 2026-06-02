import Foundation
import SwiftData

public enum Gender: String, Codable, Sendable {
    case boy
    case girl
    case preferNotToSay

    public var pronounSubject: String {
        switch self {
        case .boy: return "he"
        case .girl: return "she"
        case .preferNotToSay: return "they"
        }
    }

    public var pronounObject: String {
        switch self {
        case .boy: return "him"
        case .girl: return "her"
        case .preferNotToSay: return "them"
        }
    }

    public var pronounPossessive: String {
        switch self {
        case .boy: return "his"
        case .girl: return "her"
        case .preferNotToSay: return "their"
        }
    }
}

@Model
public final class Child {
    public var id: UUID
    public var name: String
    public var dateOfBirth: Date
    public var genderRawValue: String
    public var avatarAssetName: String = ImageAsset.childAvatar1.rawValue

    public var gender: Gender {
        get { Gender(rawValue: genderRawValue) ?? .preferNotToSay }
        set { genderRawValue = newValue.rawValue }
    }

    public var avatarImage: ChildAvatarImage? {
        guard let asset = ImageAsset(storedName: avatarAssetName) else { return nil }
        return ChildAvatarImage(asset: asset)
    }

    public init(
        id: UUID = UUID(),
        name: String,
        dateOfBirth: Date,
        gender: Gender,
        avatarAssetName: String = ImageAsset.childAvatar1.rawValue
    ) {
        self.id = id
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.genderRawValue = gender.rawValue
        self.avatarAssetName = avatarAssetName
    }

    public var currentAge: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }
}
