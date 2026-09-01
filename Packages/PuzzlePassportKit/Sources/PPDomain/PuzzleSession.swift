import Foundation

public struct PuzzleArrangement: Hashable, Codable, Sendable {
    public let occupantsByPosition: [PositionID: EntityID]

    public init(occupantsByPosition: [PositionID: EntityID] = [:]) {
        self.occupantsByPosition = occupantsByPosition
    }

    public func entity(at positionID: PositionID) -> EntityID? {
        occupantsByPosition[positionID]
    }

    public func position(of entityID: EntityID) -> PositionID? {
        occupantsByPosition.first { $0.value == entityID }?.key
    }
}

public enum PlacementOrigin: Hashable, Codable, Sendable {
    case unplaced
    case position(PositionID)
}

public struct PuzzleMove: Hashable, Codable, Sendable {
    public let entityID: EntityID
    public let from: PlacementOrigin
    public let to: PositionID
    public let displacedEntityID: EntityID?

    public init(
        entityID: EntityID,
        from: PlacementOrigin,
        to: PositionID,
        displacedEntityID: EntityID?
    ) {
        self.entityID = entityID
        self.from = from
        self.to = to
        self.displacedEntityID = displacedEntityID
    }
}

public struct PuzzleCompletionResult: Hashable, Codable, Sendable {
    public let moveCount: Int
    public let stars: StarRating

    public init(moveCount: Int, stars: StarRating) {
        self.moveCount = moveCount
        self.stars = stars
    }
}

public enum PuzzleSessionStatus: Hashable, Codable, Sendable {
    case inProgress
    case completed(PuzzleCompletionResult)
    /// The authored move budget ran out before the arrangement was complete.
    case failed
}

public struct PuzzleSession: Hashable, Codable, Sendable {
    public let puzzleID: PuzzleID
    public let initialArrangement: PuzzleArrangement
    public let arrangement: PuzzleArrangement
    public let moveCount: Int
    public let history: [PuzzleMove]
    public let status: PuzzleSessionStatus

    public init(
        puzzleID: PuzzleID,
        initialArrangement: PuzzleArrangement,
        arrangement: PuzzleArrangement,
        moveCount: Int,
        history: [PuzzleMove],
        status: PuzzleSessionStatus
    ) {
        self.puzzleID = puzzleID
        self.initialArrangement = initialArrangement
        self.arrangement = arrangement
        self.moveCount = moveCount
        self.history = history
        self.status = status
    }
}

public enum PuzzleHint: Hashable, Codable, Sendable {
    case forcedPlacement(entity: EntityID, position: PositionID)
}

public enum ConstraintSatisfaction: Hashable, Sendable {
    case satisfied
    case violated
    case undetermined
}

public struct ConstraintEvaluation: Hashable, Sendable {
    public let constraint: PuzzleConstraint
    public let satisfaction: ConstraintSatisfaction

    public init(constraint: PuzzleConstraint, satisfaction: ConstraintSatisfaction) {
        self.constraint = constraint
        self.satisfaction = satisfaction
    }
}

public enum PuzzleAction: Hashable, Sendable {
    case place(entity: EntityID, at: PositionID)
    case cancelPlacement
    case undo
    case restart
}
