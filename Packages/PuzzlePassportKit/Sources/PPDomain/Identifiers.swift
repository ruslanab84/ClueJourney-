import Foundation

public struct StableID<Tag>: RawRepresentable, Hashable, Comparable, Codable, Sendable,
    CustomStringConvertible
{
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Stable identifiers must not be empty."
            )
        }
        rawValue = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String { rawValue }
}

public enum PuzzleIDTag: Sendable {}
public enum EntityIDTag: Sendable {}
public enum PositionIDTag: Sendable {}

public typealias PuzzleID = StableID<PuzzleIDTag>
public typealias EntityID = StableID<EntityIDTag>
public typealias PositionID = StableID<PositionIDTag>
