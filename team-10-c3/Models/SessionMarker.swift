import Foundation
import SwiftData

@Model
public final class SessionMarker {
    public var id: UUID
    public var childId: UUID
    public var timestamp: Date
    public var typeRaw: String

    public var type: SessionMarkerType {
        get { SessionMarkerType(rawValue: typeRaw) ?? .start }
        set { typeRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        childId: UUID,
        timestamp: Date = Date(),
        type: SessionMarkerType
    ) {
        self.id = id
        self.childId = childId
        self.timestamp = timestamp
        self.typeRaw = type.rawValue
    }
}
