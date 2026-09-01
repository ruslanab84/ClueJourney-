import Foundation

public struct GridCoordinate: Hashable, Codable, Sendable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}

public struct PuzzleEntity: Identifiable, Hashable, Codable, Sendable {
    public let id: EntityID

    public init(id: EntityID) {
        self.id = id
    }
}

public struct PuzzlePosition: Identifiable, Hashable, Codable, Sendable {
    public let id: PositionID
    public let coordinate: GridCoordinate

    public init(id: PositionID, coordinate: GridCoordinate) {
        self.id = id
        self.coordinate = coordinate
    }
}

public struct InitialAssignment: Hashable, Codable, Sendable {
    public let entityID: EntityID
    public let positionID: PositionID
    public let isLocked: Bool

    public init(entityID: EntityID, positionID: PositionID, isLocked: Bool = false) {
        self.entityID = entityID
        self.positionID = positionID
        self.isLocked = isLocked
    }
}

public enum PuzzleConstraint: Hashable, Codable, Sendable {
    case assigned(entity: EntityID, position: PositionID)
    case excluded(entity: EntityID, position: PositionID)
    case adjacent(EntityID, EntityID)
    case notAdjacent(EntityID, EntityID)
    case leftOf(EntityID, EntityID)
    case immediatelyLeftOf(EntityID, EntityID)
    case sameRow(EntityID, EntityID)
    case differentRow(EntityID, EntityID)
}

public enum OccupiedDropPolicy: String, Hashable, Codable, Sendable {
    case reject
    case swap
}

public enum UndoScoringPolicy: String, Hashable, Codable, Sendable {
    case restoresPreviousMoveCount
    case countsAsMove
}

public enum PlacementPolicy: String, Hashable, Codable, Sendable {
    /// Any structurally legal placement is accepted; clues report their state.
    case free
    /// A placement that no solution can extend is refused, and the attempt still spends a move.
    case verified
}

public struct MovePolicy: Hashable, Codable, Sendable {
    public let occupiedDrop: OccupiedDropPolicy
    public let undoScoring: UndoScoringPolicy
    public let placement: PlacementPolicy
    public let moveLimit: Int?

    public init(
        occupiedDrop: OccupiedDropPolicy,
        undoScoring: UndoScoringPolicy = .restoresPreviousMoveCount,
        placement: PlacementPolicy = .free,
        moveLimit: Int? = nil
    ) {
        self.occupiedDrop = occupiedDrop
        self.undoScoring = undoScoring
        self.placement = placement
        self.moveLimit = moveLimit
    }
}

public enum StarRating: Int, Hashable, Codable, Sendable {
    case one = 1
    case two = 2
    case three = 3
}

public struct StarThresholds: Hashable, Codable, Sendable {
    public let threeStarMaximumMoves: Int
    public let twoStarMaximumMoves: Int

    public init(threeStarMaximumMoves: Int, twoStarMaximumMoves: Int) {
        self.threeStarMaximumMoves = threeStarMaximumMoves
        self.twoStarMaximumMoves = twoStarMaximumMoves
    }

    public func rating(for moveCount: Int) -> StarRating {
        if moveCount <= threeStarMaximumMoves { return .three }
        if moveCount <= twoStarMaximumMoves { return .two }
        return .one
    }
}

public struct PuzzleDefinition: Hashable, Codable, Sendable {
    public let id: PuzzleID
    public let entities: [PuzzleEntity]
    public let positions: [PuzzlePosition]
    public let constraints: [PuzzleConstraint]
    public let initialAssignments: [InitialAssignment]
    public let movePolicy: MovePolicy
    public let starThresholds: StarThresholds

    public init(
        id: PuzzleID,
        entities: [PuzzleEntity],
        positions: [PuzzlePosition],
        constraints: [PuzzleConstraint],
        initialAssignments: [InitialAssignment] = [],
        movePolicy: MovePolicy,
        starThresholds: StarThresholds
    ) {
        self.id = id
        self.entities = entities
        self.positions = positions
        self.constraints = constraints
        self.initialAssignments = initialAssignments
        self.movePolicy = movePolicy
        self.starThresholds = starThresholds
    }
}
