import Foundation

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

public struct Child: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var dateOfBirth: Date
    public var gender: Gender
    
    public init(id: UUID = UUID(), name: String, dateOfBirth: Date, gender: Gender) {
        self.id = id
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.gender = gender
    }
    
    public var currentAge: Int {
        return Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }
}
