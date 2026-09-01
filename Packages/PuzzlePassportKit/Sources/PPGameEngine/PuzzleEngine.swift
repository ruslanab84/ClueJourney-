import Foundation
import PPDomain

public enum PuzzleDefinitionIssue: Hashable, Sendable {
    case emptyPuzzleID
    case noEntities
    case noPositions
    case emptyEntityID(EntityID)
    case emptyPositionID(PositionID)
    case duplicateEntity(EntityID)
    case duplicatePosition(PositionID)
    case duplicateCoordinate(GridCoordinate)
    case unknownInitialEntity(EntityID)
    case unknownInitialPosition(PositionID)
    case duplicateInitialEntity(EntityID)
    case duplicateInitialPosition(PositionID)
    case unknownConstraintEntity(EntityID)
    case unknownConstraintPosition(PositionID)
    case selfReferentialConstraint(PuzzleConstraint)
    case invalidStarThresholds
}

public struct PuzzleDefinitionValidation: Hashable, Sendable {
    public let issues: [PuzzleDefinitionIssue]

    public init(issues: [PuzzleDefinitionIssue]) {
        self.issues = issues
    }

    public var isValid: Bool { issues.isEmpty }
}

public enum PuzzleArrangementIssue: Hashable, Sendable {
    case unknownEntity(EntityID)
    case unknownPosition(PositionID)
    case entityAssignedMultipleTimes(EntityID)
    case lockedAssignmentChanged(entity: EntityID, position: PositionID)
}

public struct PuzzleArrangementValidation: Hashable, Sendable {
    public let issues: [PuzzleArrangementIssue]
    public let constraintEvaluations: [ConstraintEvaluation]
    public let missingEntities: [EntityID]

    public init(
        issues: [PuzzleArrangementIssue],
        constraintEvaluations: [ConstraintEvaluation],
        missingEntities: [EntityID]
    ) {
        self.issues = issues
        self.constraintEvaluations = constraintEvaluations
        self.missingEntities = missingEntities
    }

    public var isConsistent: Bool {
        issues.isEmpty && !constraintEvaluations.contains { $0.satisfaction == .violated }
    }

    public var isComplete: Bool {
        issues.isEmpty
            && missingEntities.isEmpty
            && constraintEvaluations.allSatisfy { $0.satisfaction == .satisfied }
    }
}

public enum PuzzleEngineError: Error, Hashable, Sendable {
    case invalidDefinition([PuzzleDefinitionIssue])
    case invalidSolutionLimit(Int)
    case invalidSession([PuzzleArrangementIssue])
    case puzzleMismatch(expected: PuzzleID, actual: PuzzleID)
}

public enum PuzzleMoveRejection: Hashable, Sendable {
    case unknownEntity(EntityID)
    case unknownPosition(PositionID)
    case entityLocked(EntityID)
    case positionLocked(PositionID)
    case occupied(PositionID)
    case sessionCompleted
}

public enum PuzzleTransitionOutcome: Hashable, Sendable {
    case rejected(PuzzleMoveRejection)
    case unchanged
    case moved(PuzzleMove)
    case undone(PuzzleMove)
    case restarted
}

public struct PuzzleTransition: Hashable, Sendable {
    public let session: PuzzleSession
    public let outcome: PuzzleTransitionOutcome

    public init(session: PuzzleSession, outcome: PuzzleTransitionOutcome) {
        self.session = session
        self.outcome = outcome
    }
}

public struct PuzzleEngine: Sendable {
    public init() {}

    public func validate(_ definition: PuzzleDefinition) -> PuzzleDefinitionValidation {
        var issues: [PuzzleDefinitionIssue] = []

        if isBlank(definition.id.rawValue) { issues.append(.emptyPuzzleID) }
        if definition.entities.isEmpty { issues.append(.noEntities) }
        if definition.positions.isEmpty { issues.append(.noPositions) }

        var entityIDs = Set<EntityID>()
        for entity in definition.entities {
            if isBlank(entity.id.rawValue) { issues.append(.emptyEntityID(entity.id)) }
            if !entityIDs.insert(entity.id).inserted { issues.append(.duplicateEntity(entity.id)) }
        }

        var positionIDs = Set<PositionID>()
        var coordinates = Set<GridCoordinate>()
        for position in definition.positions {
            if isBlank(position.id.rawValue) { issues.append(.emptyPositionID(position.id)) }
            if !positionIDs.insert(position.id).inserted {
                issues.append(.duplicatePosition(position.id))
            }
            if !coordinates.insert(position.coordinate).inserted {
                issues.append(.duplicateCoordinate(position.coordinate))
            }
        }

        var initiallyAssignedEntities = Set<EntityID>()
        var initiallyOccupiedPositions = Set<PositionID>()
        for assignment in definition.initialAssignments {
            if !entityIDs.contains(assignment.entityID) {
                issues.append(.unknownInitialEntity(assignment.entityID))
            }
            if !positionIDs.contains(assignment.positionID) {
                issues.append(.unknownInitialPosition(assignment.positionID))
            }
            if !initiallyAssignedEntities.insert(assignment.entityID).inserted {
                issues.append(.duplicateInitialEntity(assignment.entityID))
            }
            if !initiallyOccupiedPositions.insert(assignment.positionID).inserted {
                issues.append(.duplicateInitialPosition(assignment.positionID))
            }
        }

        for constraint in definition.constraints {
            for entityID in referencedEntities(in: constraint) where !entityIDs.contains(entityID) {
                issues.append(.unknownConstraintEntity(entityID))
            }
            for positionID in referencedPositions(in: constraint) where !positionIDs.contains(positionID) {
                issues.append(.unknownConstraintPosition(positionID))
            }
            if isSelfReferential(constraint) {
                issues.append(.selfReferentialConstraint(constraint))
            }
        }

        let thresholds = definition.starThresholds
        if thresholds.threeStarMaximumMoves < 0
            || thresholds.twoStarMaximumMoves < thresholds.threeStarMaximumMoves
        {
            issues.append(.invalidStarThresholds)
        }

        return PuzzleDefinitionValidation(issues: issues)
    }

    public func validate(
        _ arrangement: PuzzleArrangement,
        for definition: PuzzleDefinition
    ) -> PuzzleArrangementValidation {
        let knownEntities = Set(definition.entities.map(\.id))
        let knownPositions = Set(definition.positions.map(\.id))
        let sortedAssignments = arrangement.occupantsByPosition.sorted { $0.key < $1.key }
        var issues: [PuzzleArrangementIssue] = []
        var assignedEntities = Set<EntityID>()

        for (positionID, entityID) in sortedAssignments {
            if !knownPositions.contains(positionID) { issues.append(.unknownPosition(positionID)) }
            if !knownEntities.contains(entityID) { issues.append(.unknownEntity(entityID)) }
            if !assignedEntities.insert(entityID).inserted {
                issues.append(.entityAssignedMultipleTimes(entityID))
            }
        }

        for assignment in definition.initialAssignments where assignment.isLocked {
            if arrangement.entity(at: assignment.positionID) != assignment.entityID {
                issues.append(
                    .lockedAssignmentChanged(
                        entity: assignment.entityID,
                        position: assignment.positionID
                    )
                )
            }
        }

        let evaluations = definition.constraints.map {
            ConstraintEvaluation(
                constraint: $0,
                satisfaction: evaluate($0, in: arrangement, for: definition)
            )
        }
        let missingEntities = knownEntities.subtracting(assignedEntities).sorted()

        return PuzzleArrangementValidation(
            issues: issues,
            constraintEvaluations: evaluations,
            missingEntities: missingEntities
        )
    }

    public func evaluate(
        _ constraint: PuzzleConstraint,
        in arrangement: PuzzleArrangement,
        for definition: PuzzleDefinition
    ) -> ConstraintSatisfaction {
        let entityPositions = positionsByEntity(in: arrangement)
        let coordinates = Dictionary(
            uniqueKeysWithValues: definition.positions.map { ($0.id, $0.coordinate) }
        )

        switch constraint {
        case .assigned(let entityID, let positionID):
            guard let actual = entityPositions[entityID] else { return .undetermined }
            return actual == positionID ? .satisfied : .violated

        case .excluded(let entityID, let positionID):
            guard let actual = entityPositions[entityID] else { return .undetermined }
            return actual != positionID ? .satisfied : .violated

        case .adjacent(let first, let second):
            return evaluatePair(first, second, entityPositions, coordinates) {
                $0.row == $1.row && columnsAreAdjacent($0.column, $1.column)
            }

        case .notAdjacent(let first, let second):
            return evaluatePair(first, second, entityPositions, coordinates) {
                !($0.row == $1.row && columnsAreAdjacent($0.column, $1.column))
            }

        case .leftOf(let first, let second):
            return evaluatePair(first, second, entityPositions, coordinates) {
                $0.row == $1.row && $0.column < $1.column
            }

        case .immediatelyLeftOf(let first, let second):
            return evaluatePair(first, second, entityPositions, coordinates) {
                guard $0.row == $1.row else { return false }
                let (nextColumn, overflow) = $0.column.addingReportingOverflow(1)
                return !overflow && nextColumn == $1.column
            }

        case .sameRow(let first, let second):
            return evaluatePair(first, second, entityPositions, coordinates) {
                $0.row == $1.row
            }

        case .differentRow(let first, let second):
            return evaluatePair(first, second, entityPositions, coordinates) {
                $0.row != $1.row
            }
        }
    }

    public func start(_ definition: PuzzleDefinition) throws -> PuzzleSession {
        try requireValid(definition)
        let initial = PuzzleArrangement(
            occupantsByPosition: Dictionary(
                uniqueKeysWithValues: definition.initialAssignments.map {
                    ($0.positionID, $0.entityID)
                }
            )
        )
        let initialValidation = validate(initial, for: definition)
        guard initialValidation.issues.isEmpty else {
            throw PuzzleEngineError.invalidSession(initialValidation.issues)
        }
        return makeSession(
            puzzleID: definition.id,
            initial: initial,
            arrangement: initial,
            moveCount: 0,
            history: [],
            definition: definition
        )
    }

    public func apply(
        _ action: PuzzleAction,
        to session: PuzzleSession,
        in definition: PuzzleDefinition
    ) throws -> PuzzleTransition {
        try requireValid(definition)
        guard session.puzzleID == definition.id else {
            throw PuzzleEngineError.puzzleMismatch(
                expected: definition.id,
                actual: session.puzzleID
            )
        }
        let sessionValidation = validate(session.arrangement, for: definition)
        guard sessionValidation.issues.isEmpty else {
            throw PuzzleEngineError.invalidSession(sessionValidation.issues)
        }

        switch action {
        case .cancelPlacement:
            return PuzzleTransition(session: session, outcome: .unchanged)
        case .restart:
            return restart(session, definition: definition)
        case .undo:
            return undo(session, definition: definition)
        case .place(let entityID, let positionID):
            return place(entityID, at: positionID, in: session, definition: definition)
        }
    }

    public func solutionCount(
        for definition: PuzzleDefinition,
        limit: Int = 2
    ) throws -> Int {
        try solutions(
            for: definition,
            seed: lockedArrangement(for: definition),
            limit: limit
        ).count
    }

    public func hint(
        for session: PuzzleSession,
        in definition: PuzzleDefinition
    ) throws -> PuzzleHint? {
        try requireValid(definition)
        guard session.puzzleID == definition.id else {
            throw PuzzleEngineError.puzzleMismatch(
                expected: definition.id,
                actual: session.puzzleID
            )
        }
        let sessionValidation = validate(session.arrangement, for: definition)
        guard sessionValidation.issues.isEmpty else {
            throw PuzzleEngineError.invalidSession(sessionValidation.issues)
        }

        let candidates = try solutions(
            for: definition,
            seed: lockedArrangement(for: definition),
            limit: 2
        )
        guard candidates.count == 1, let solution = candidates.first else { return nil }

        for entityID in definition.entities.map(\.id).sorted()
        where session.arrangement.position(of: entityID) != solution.position(of: entityID) {
            guard let positionID = solution.position(of: entityID) else { continue }
            return .forcedPlacement(entity: entityID, position: positionID)
        }
        return nil
    }

    private func place(
        _ entityID: EntityID,
        at targetPositionID: PositionID,
        in session: PuzzleSession,
        definition: PuzzleDefinition
    ) -> PuzzleTransition {
        if case .completed = session.status {
            return PuzzleTransition(session: session, outcome: .rejected(.sessionCompleted))
        }

        let knownEntities = Set(definition.entities.map(\.id))
        guard knownEntities.contains(entityID) else {
            return PuzzleTransition(session: session, outcome: .rejected(.unknownEntity(entityID)))
        }
        let knownPositions = Set(definition.positions.map(\.id))
        guard knownPositions.contains(targetPositionID) else {
            return PuzzleTransition(
                session: session,
                outcome: .rejected(.unknownPosition(targetPositionID))
            )
        }

        let lockedAssignments = definition.initialAssignments.filter(\.isLocked)
        if lockedAssignments.contains(where: { $0.entityID == entityID }) {
            return PuzzleTransition(session: session, outcome: .rejected(.entityLocked(entityID)))
        }

        let sourcePositionID = session.arrangement.position(of: entityID)
        if sourcePositionID == targetPositionID {
            return PuzzleTransition(session: session, outcome: .unchanged)
        }

        let displacedEntityID = session.arrangement.entity(at: targetPositionID)
        if lockedAssignments.contains(where: {
            $0.positionID == targetPositionID && $0.entityID == displacedEntityID
        }) {
            return PuzzleTransition(
                session: session,
                outcome: .rejected(.positionLocked(targetPositionID))
            )
        }

        if displacedEntityID != nil, definition.movePolicy.occupiedDrop == .reject {
            return PuzzleTransition(
                session: session,
                outcome: .rejected(.occupied(targetPositionID))
            )
        }

        var occupants = session.arrangement.occupantsByPosition
        if let sourcePositionID { occupants.removeValue(forKey: sourcePositionID) }
        occupants.removeValue(forKey: targetPositionID)
        occupants[targetPositionID] = entityID
        if let displacedEntityID, let sourcePositionID {
            occupants[sourcePositionID] = displacedEntityID
        }

        let move = PuzzleMove(
            entityID: entityID,
            from: sourcePositionID.map(PlacementOrigin.position) ?? .unplaced,
            to: targetPositionID,
            displacedEntityID: displacedEntityID
        )
        let nextSession = makeSession(
            puzzleID: session.puzzleID,
            initial: session.initialArrangement,
            arrangement: PuzzleArrangement(occupantsByPosition: occupants),
            moveCount: session.moveCount + 1,
            history: session.history + [move],
            definition: definition
        )
        return PuzzleTransition(session: nextSession, outcome: .moved(move))
    }

    private func undo(
        _ session: PuzzleSession,
        definition: PuzzleDefinition
    ) -> PuzzleTransition {
        guard let move = session.history.last else {
            return PuzzleTransition(session: session, outcome: .unchanged)
        }

        var occupants = session.arrangement.occupantsByPosition
        occupants.removeValue(forKey: move.to)
        if let displacedEntityID = move.displacedEntityID {
            occupants[move.to] = displacedEntityID
        }
        if case .position(let sourcePositionID) = move.from {
            occupants[sourcePositionID] = move.entityID
        }

        let moveCount: Int
        switch definition.movePolicy.undoScoring {
        case .restoresPreviousMoveCount:
            moveCount = max(0, session.moveCount - 1)
        case .countsAsMove:
            moveCount = session.moveCount + 1
        }

        let nextSession = makeSession(
            puzzleID: session.puzzleID,
            initial: session.initialArrangement,
            arrangement: PuzzleArrangement(occupantsByPosition: occupants),
            moveCount: moveCount,
            history: Array(session.history.dropLast()),
            definition: definition
        )
        return PuzzleTransition(session: nextSession, outcome: .undone(move))
    }

    private func restart(
        _ session: PuzzleSession,
        definition: PuzzleDefinition
    ) -> PuzzleTransition {
        let restarted = makeSession(
            puzzleID: session.puzzleID,
            initial: session.initialArrangement,
            arrangement: session.initialArrangement,
            moveCount: 0,
            history: [],
            definition: definition
        )
        return PuzzleTransition(session: restarted, outcome: .restarted)
    }

    private func makeSession(
        puzzleID: PuzzleID,
        initial: PuzzleArrangement,
        arrangement: PuzzleArrangement,
        moveCount: Int,
        history: [PuzzleMove],
        definition: PuzzleDefinition
    ) -> PuzzleSession {
        let validation = validate(arrangement, for: definition)
        let status: PuzzleSessionStatus
        if validation.isComplete {
            status = .completed(
                PuzzleCompletionResult(
                    moveCount: moveCount,
                    stars: definition.starThresholds.rating(for: moveCount)
                )
            )
        } else {
            status = .inProgress
        }
        return PuzzleSession(
            puzzleID: puzzleID,
            initialArrangement: initial,
            arrangement: arrangement,
            moveCount: moveCount,
            history: history,
            status: status
        )
    }

    private func solutions(
        for definition: PuzzleDefinition,
        seed: PuzzleArrangement,
        limit: Int
    ) throws -> [PuzzleArrangement] {
        guard limit > 0 else { throw PuzzleEngineError.invalidSolutionLimit(limit) }
        try requireValid(definition)
        let seedValidation = validate(seed, for: definition)
        guard seedValidation.issues.isEmpty else {
            throw PuzzleEngineError.invalidSession(seedValidation.issues)
        }

        let entityIDs = definition.entities.map(\.id).sorted()
        let positionIDs = definition.positions.map(\.id).sorted()
        var found: [PuzzleArrangement] = []

        func search(_ arrangement: PuzzleArrangement) throws {
            try Task.checkCancellation()
            guard found.count < limit else { return }

            let unassigned = entityIDs.filter { arrangement.position(of: $0) == nil }
            guard !unassigned.isEmpty else {
                if validate(arrangement, for: definition).isComplete {
                    found.append(arrangement)
                }
                return
            }

            var selectedEntity: EntityID?
            var selectedPositions: [PositionID] = []

            for entityID in unassigned {
                let positions = positionIDs.filter { positionID in
                    guard arrangement.entity(at: positionID) == nil else { return false }
                    var occupants = arrangement.occupantsByPosition
                    occupants[positionID] = entityID
                    let candidate = PuzzleArrangement(occupantsByPosition: occupants)
                    return definition.constraints.allSatisfy {
                        evaluate($0, in: candidate, for: definition) != .violated
                    }
                }
                if selectedEntity == nil || positions.count < selectedPositions.count {
                    selectedEntity = entityID
                    selectedPositions = positions
                }
            }

            guard let selectedEntity, !selectedPositions.isEmpty else { return }
            for positionID in selectedPositions {
                guard found.count < limit else { return }
                var occupants = arrangement.occupantsByPosition
                occupants[positionID] = selectedEntity
                try search(PuzzleArrangement(occupantsByPosition: occupants))
            }
        }

        try search(seed)
        return found
    }

    private func lockedArrangement(for definition: PuzzleDefinition) -> PuzzleArrangement {
        PuzzleArrangement(
            occupantsByPosition: Dictionary(
                uniqueKeysWithValues: definition.initialAssignments.lazy
                    .filter(\.isLocked)
                    .map { ($0.positionID, $0.entityID) }
            )
        )
    }

    private func requireValid(_ definition: PuzzleDefinition) throws {
        let result = validate(definition)
        guard result.isValid else { throw PuzzleEngineError.invalidDefinition(result.issues) }
    }

    private func positionsByEntity(in arrangement: PuzzleArrangement) -> [EntityID: PositionID] {
        var result: [EntityID: PositionID] = [:]
        for (positionID, entityID) in arrangement.occupantsByPosition.sorted(by: { $0.key < $1.key }) {
            if result[entityID] == nil { result[entityID] = positionID }
        }
        return result
    }

    private func evaluatePair(
        _ firstEntityID: EntityID,
        _ secondEntityID: EntityID,
        _ entityPositions: [EntityID: PositionID],
        _ coordinates: [PositionID: GridCoordinate],
        predicate: (GridCoordinate, GridCoordinate) -> Bool
    ) -> ConstraintSatisfaction {
        guard
            let firstPositionID = entityPositions[firstEntityID],
            let secondPositionID = entityPositions[secondEntityID],
            let first = coordinates[firstPositionID],
            let second = coordinates[secondPositionID]
        else {
            return .undetermined
        }
        return predicate(first, second) ? .satisfied : .violated
    }

    private func columnsAreAdjacent(_ first: Int, _ second: Int) -> Bool {
        let (afterFirst, firstOverflow) = first.addingReportingOverflow(1)
        let (afterSecond, secondOverflow) = second.addingReportingOverflow(1)
        return (!firstOverflow && afterFirst == second)
            || (!secondOverflow && afterSecond == first)
    }

    private func referencedEntities(in constraint: PuzzleConstraint) -> [EntityID] {
        switch constraint {
        case .assigned(let entityID, _), .excluded(let entityID, _):
            [entityID]
        case .adjacent(let first, let second),
            .notAdjacent(let first, let second),
            .leftOf(let first, let second),
            .immediatelyLeftOf(let first, let second),
            .sameRow(let first, let second),
            .differentRow(let first, let second):
            [first, second]
        }
    }

    private func referencedPositions(in constraint: PuzzleConstraint) -> [PositionID] {
        switch constraint {
        case .assigned(_, let positionID), .excluded(_, let positionID):
            [positionID]
        case .adjacent, .notAdjacent, .leftOf, .immediatelyLeftOf, .sameRow, .differentRow:
            []
        }
    }

    private func isSelfReferential(_ constraint: PuzzleConstraint) -> Bool {
        let entities = referencedEntities(in: constraint)
        return entities.count == 2 && entities[0] == entities[1]
    }

    private func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
