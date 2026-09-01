import PPDomain
import PPGameEngine
import Testing

@Suite("Deterministic puzzle engine")
struct PuzzleEngineTests {
    private let engine = PuzzleEngine()

    @Test("A constrained spatial puzzle has one solution")
    func uniqueSolution() throws {
        let definition = makeDefinition(
            constraints: [.immediatelyLeftOf(.a, .b)]
        )

        #expect(try engine.solutionCount(for: definition, limit: 2) == 1)
    }

    @Test("Contradictory spatial constraints have no solution")
    func zeroSolutions() throws {
        let definition = makeDefinition(
            positions: [
                position(.p0, row: 0, column: 0),
                position(.p1, row: 1, column: 0),
            ],
            constraints: [.sameRow(.a, .b)]
        )

        #expect(try engine.solutionCount(for: definition, limit: 2) == 0)
    }

    @Test("Solution counting stops at the requested ambiguity limit")
    func multipleSolutions() throws {
        let definition = makeDefinition()

        #expect(try engine.solutionCount(for: definition, limit: 2) == 2)
    }

    @Test("Locked assignments cannot move or be displaced")
    func lockedAssignments() throws {
        let definition = threeEntityDefinition(
            initialAssignments: [
                InitialAssignment(entityID: .a, positionID: .p0, isLocked: true),
                InitialAssignment(entityID: .b, positionID: .p1),
            ],
            occupiedDrop: .swap
        )
        let session = try engine.start(definition)

        let movingLocked = try engine.apply(
            .place(entity: .a, at: .p2),
            to: session,
            in: definition
        )
        let displacingLocked = try engine.apply(
            .place(entity: .b, at: .p0),
            to: session,
            in: definition
        )

        #expect(movingLocked.outcome == .rejected(.entityLocked(.a)))
        #expect(displacingLocked.outcome == .rejected(.positionLocked(.p0)))
        #expect(movingLocked.session.moveCount == 0)
        #expect(displacingLocked.session.arrangement == session.arrangement)
    }

    @Test("Dropping on a movable occupant swaps both entities")
    func occupiedDropSwapsMovableEntities() throws {
        let definition = threeEntityDefinition(
            initialAssignments: [
                InitialAssignment(entityID: .a, positionID: .p0),
                InitialAssignment(entityID: .b, positionID: .p1),
            ],
            occupiedDrop: .swap
        )
        let session = try engine.start(definition)

        let transition = try engine.apply(
            .place(entity: .a, at: .p1),
            to: session,
            in: definition
        )

        #expect(transition.session.arrangement.entity(at: .p1) == .a)
        #expect(transition.session.arrangement.entity(at: .p0) == .b)
        #expect(transition.session.moveCount == 1)
        #expect(transition.session.history.count == 1)
    }

    @Test("Reject policy leaves an occupied target unchanged")
    func occupiedDropRejects() throws {
        let definition = threeEntityDefinition(
            initialAssignments: [
                InitialAssignment(entityID: .a, positionID: .p0),
                InitialAssignment(entityID: .b, positionID: .p1),
            ],
            occupiedDrop: .reject
        )
        let session = try engine.start(definition)

        let transition = try engine.apply(
            .place(entity: .a, at: .p1),
            to: session,
            in: definition
        )

        #expect(transition.outcome == .rejected(.occupied(.p1)))
        #expect(transition.session == session)
    }

    @Test("Invalid, cancelled, and same-origin placement do not count as moves")
    func nonCommittedActionsDoNotCount() throws {
        let definition = threeEntityDefinition(
            initialAssignments: [InitialAssignment(entityID: .a, positionID: .p0)],
            occupiedDrop: .swap
        )
        let session = try engine.start(definition)

        let invalid = try engine.apply(
            .place(entity: .a, at: PositionID("missing")),
            to: session,
            in: definition
        )
        let cancelled = try engine.apply(.cancelPlacement, to: session, in: definition)
        let sameOrigin = try engine.apply(
            .place(entity: .a, at: .p0),
            to: session,
            in: definition
        )

        #expect(invalid.outcome == .rejected(.unknownPosition(PositionID("missing"))))
        #expect(cancelled.outcome == .unchanged)
        #expect(sameOrigin.outcome == .unchanged)
        #expect(invalid.session.moveCount == 0)
        #expect(cancelled.session.history.isEmpty)
        #expect(sameOrigin.session.arrangement == session.arrangement)
    }

    @Test("Undo restores the prior arrangement and restart restores authored state")
    func undoAndRestart() throws {
        let definition = completionDefinition()
        let initial = try engine.start(definition)
        let completed = try engine.apply(
            .place(entity: .c, at: .p2),
            to: initial,
            in: definition
        ).session

        let undone = try engine.apply(.undo, to: completed, in: definition)
        let restarted = try engine.apply(.restart, to: completed, in: definition)

        #expect(undone.session.arrangement == initial.arrangement)
        #expect(undone.session.moveCount == 0)
        #expect(undone.session.history.isEmpty)
        #expect(undone.session.status == .inProgress)
        #expect(restarted.session.arrangement == initial.initialArrangement)
        #expect(restarted.session.moveCount == 0)
        #expect(restarted.session.history.isEmpty)
    }

    @Test("Completion records authored star thresholds")
    func completionStars() throws {
        let definition = completionDefinition()
        let session = try engine.start(definition)

        let completed = try engine.apply(
            .place(entity: .c, at: .p2),
            to: session,
            in: definition
        ).session
        let result = try #require(completionResult(from: completed.status))

        #expect(result.moveCount == 1)
        #expect(result.stars == .three)
    }

    @Test("Hint derives a forced placement from the unique solution")
    func hintDerivation() throws {
        let definition = makeDefinition(
            constraints: [.immediatelyLeftOf(.a, .b)]
        )
        let session = try engine.start(definition)

        let hint = try engine.hint(for: session, in: definition)

        #expect(hint == .forcedPlacement(entity: .a, position: .p0))
    }

    @Test("Hint corrects a movable entity placed in the wrong seat")
    func hintCorrectsWrongPlacement() throws {
        let definition = makeDefinition(
            constraints: [.immediatelyLeftOf(.a, .b)]
        )
        let initial = try engine.start(definition)
        let wrong = try engine.apply(
            .place(entity: .a, at: .p1),
            to: initial,
            in: definition
        ).session

        #expect(try engine.hint(for: wrong, in: definition) == .forcedPlacement(entity: .a, position: .p0))
    }

    @Test("Verified placement refuses a seat no solution can reach and still spends a move")
    func verifiedPlacementRefusesAndCharges() throws {
        let definition = verifiedDefinition(moveLimit: 5)
        let session = try engine.start(definition)

        let refused = try engine.apply(.place(entity: .a, at: .p1), to: session, in: definition)

        #expect(refused.outcome == .rejected(.contradictsClues(.p1)))
        #expect(refused.session.arrangement == session.arrangement)
        #expect(refused.session.history.isEmpty)
        #expect(refused.session.moveCount == 1)
        #expect(refused.session.status == .inProgress)
    }

    @Test("Verified placement seats an entity the solution agrees with")
    func verifiedPlacementSeatsCorrectEntity() throws {
        let definition = verifiedDefinition(moveLimit: 5)
        let session = try engine.start(definition)

        let seated = try engine.apply(.place(entity: .a, at: .p0), to: session, in: definition)

        #expect(seated.session.arrangement.entity(at: .p0) == .a)
        #expect(seated.session.moveCount == 1)
        #expect(seated.session.history.count == 1)
    }

    @Test("Free placement still accepts a seat that contradicts the clues")
    func freePlacementAcceptsContradiction() throws {
        let definition = completionDefinition()
        let session = try engine.start(definition)

        let transition = try engine.apply(.place(entity: .c, at: .p0), to: session, in: definition)

        #expect(transition.session.arrangement.entity(at: .p0) == .c)
        #expect(transition.session.moveCount == 1)
    }

    @Test("Spending the authored budget fails the session and closes the board")
    func exhaustedBudgetFailsSession() throws {
        let definition = verifiedDefinition(moveLimit: 2)
        let session = try engine.start(definition)

        let first = try engine.apply(.place(entity: .a, at: .p1), to: session, in: definition)
        let second = try engine.apply(.place(entity: .a, at: .p2), to: first.session, in: definition)
        let afterFailure = try engine.apply(
            .place(entity: .a, at: .p0),
            to: second.session,
            in: definition
        )

        #expect(second.session.status == .failed)
        #expect(afterFailure.outcome == .rejected(.sessionFailed))
        #expect(afterFailure.session.arrangement == session.arrangement)
        #expect(afterFailure.session.moveCount == 2)
    }

    @Test("A budget is only spent by refusals and moves, never by blocked attempts")
    func blockedAttemptsSpendNothing() throws {
        let definition = verifiedDefinition(moveLimit: 3)
        let session = try engine.start(definition)

        let unknown = try engine.apply(
            .place(entity: .a, at: PositionID("missing")),
            to: session,
            in: definition
        )

        #expect(unknown.outcome == .rejected(.unknownPosition(PositionID("missing"))))
        #expect(unknown.session.moveCount == 0)
    }
}

private extension PuzzleEngineTests {
    func makeDefinition(
        positions: [PuzzlePosition]? = nil,
        constraints: [PuzzleConstraint] = []
    ) -> PuzzleDefinition {
        PuzzleDefinition(
            id: PuzzleID("test.puzzle"),
            entities: [PuzzleEntity(id: .a), PuzzleEntity(id: .b)],
            positions: positions ?? [
                position(.p0, row: 0, column: 0),
                position(.p1, row: 0, column: 1),
            ],
            constraints: constraints,
            movePolicy: MovePolicy(occupiedDrop: .swap),
            starThresholds: StarThresholds(
                threeStarMaximumMoves: 2,
                twoStarMaximumMoves: 4
            )
        )
    }

    func threeEntityDefinition(
        initialAssignments: [InitialAssignment],
        occupiedDrop: OccupiedDropPolicy
    ) -> PuzzleDefinition {
        PuzzleDefinition(
            id: PuzzleID("test.three-entity"),
            entities: [PuzzleEntity(id: .a), PuzzleEntity(id: .b), PuzzleEntity(id: .c)],
            positions: [
                position(.p0, row: 0, column: 0),
                position(.p1, row: 0, column: 1),
                position(.p2, row: 0, column: 2),
            ],
            constraints: [],
            initialAssignments: initialAssignments,
            movePolicy: MovePolicy(occupiedDrop: occupiedDrop),
            starThresholds: StarThresholds(
                threeStarMaximumMoves: 2,
                twoStarMaximumMoves: 4
            )
        )
    }

    /// One seat per entity, so every seat but the authored one refuses its guest.
    func verifiedDefinition(moveLimit: Int) -> PuzzleDefinition {
        PuzzleDefinition(
            id: PuzzleID("test.verified"),
            entities: [PuzzleEntity(id: .a), PuzzleEntity(id: .b), PuzzleEntity(id: .c)],
            positions: [
                position(.p0, row: 0, column: 0),
                position(.p1, row: 0, column: 1),
                position(.p2, row: 0, column: 2),
            ],
            constraints: [
                .assigned(entity: .a, position: .p0),
                .assigned(entity: .b, position: .p1),
                .assigned(entity: .c, position: .p2),
            ],
            movePolicy: MovePolicy(
                occupiedDrop: .swap,
                placement: .verified,
                moveLimit: moveLimit
            ),
            starThresholds: StarThresholds(
                threeStarMaximumMoves: 3,
                twoStarMaximumMoves: 4
            )
        )
    }

    func completionDefinition() -> PuzzleDefinition {
        PuzzleDefinition(
            id: PuzzleID("test.completion"),
            entities: [PuzzleEntity(id: .a), PuzzleEntity(id: .b), PuzzleEntity(id: .c)],
            positions: [
                position(.p0, row: 0, column: 0),
                position(.p1, row: 0, column: 1),
                position(.p2, row: 0, column: 2),
            ],
            constraints: [
                .assigned(entity: .a, position: .p0),
                .assigned(entity: .b, position: .p1),
                .assigned(entity: .c, position: .p2),
            ],
            initialAssignments: [
                InitialAssignment(entityID: .a, positionID: .p0),
                InitialAssignment(entityID: .b, positionID: .p1),
            ],
            movePolicy: MovePolicy(occupiedDrop: .swap),
            starThresholds: StarThresholds(
                threeStarMaximumMoves: 1,
                twoStarMaximumMoves: 2
            )
        )
    }

    func position(_ id: PositionID, row: Int, column: Int) -> PuzzlePosition {
        PuzzlePosition(id: id, coordinate: GridCoordinate(row: row, column: column))
    }

    func completionResult(from status: PuzzleSessionStatus) -> PuzzleCompletionResult? {
        guard case .completed(let result) = status else { return nil }
        return result
    }
}

private extension EntityID {
    static let a = EntityID("a")
    static let b = EntityID("b")
    static let c = EntityID("c")
}

private extension PositionID {
    static let p0 = PositionID("p0")
    static let p1 = PositionID("p1")
    static let p2 = PositionID("p2")
}
