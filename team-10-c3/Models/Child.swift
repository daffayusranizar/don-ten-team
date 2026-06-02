import Foundation

public enum Gender: String, Codable, Sendable {
    case boy
    case girl

}

public struct Child: Identifiable, Codable, Sendable, Hashable {
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
