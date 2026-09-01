import Foundation
import PPApplication
import PPDomain
import Testing

@Suite("Puzzle journey orchestration")
struct PuzzleJourneyTests {
    @Test("Completion persists progress and unlocks the authored fact")
    func completionPersistsBeforeReturning() async throws {
        let level = testLevel()
        let fact = TravelFact(
            id: level.factID,
            locationID: level.locationID,
            titleKey: "fact.title",
            bodyKey: "fact.body",
            unlockLevelID: level.id,
            source: FactSource(
                title: "Source",
                url: try #require(URL(string: "https://example.com")),
                accessed: "2026-09-01"
            )
        )
        let progressRepository = RecordingProgressRepository()
        let journey = PuzzleJourney(
            contentRepository: StubContentRepository(level: level, fact: fact),
            progressRepository: progressRepository
        )

        let experience = try await journey.start(levelID: level.id)
        let update = try await journey.advance(
            .place(entity: EntityID("guest"), at: PositionID("seat")),
            from: experience
        )
        let outcome = try #require(update.completion)

        #expect(outcome.fact.id == fact.id)
        #expect(outcome.progress.levels[level.id]?.isCompleted == true)
        #expect(await progressRepository.recordedFactID() == fact.id)
    }

    @Test("A verified level reports refused and seated placements to presentation")
    func verifiedPlacementFeedback() async throws {
        let level = verifiedLevel()
        let journey = try PuzzleJourney(
            contentRepository: StubContentRepository(level: level, fact: testFact(for: level)),
            progressRepository: RecordingProgressRepository()
        )

        let experience = try await journey.start(levelID: level.id)
        let refused = try await journey.advance(
            .place(entity: EntityID("guest"), at: PositionID("aisle")),
            from: experience
        )
        let seated = try await journey.advance(
            .place(entity: EntityID("guest"), at: PositionID("seat")),
            from: refused.experience
        )

        #expect(refused.feedback == .refused)
        #expect(refused.completion == nil)
        #expect(refused.experience.session.moveCount == 1)
        #expect(seated.feedback == .seated)
        #expect(seated.experience.session.arrangement.entity(at: PositionID("seat")) == EntityID("guest"))
    }

    private func testFact(for level: CampaignLevel) throws -> TravelFact {
        try TravelFact(
            id: level.factID,
            locationID: level.locationID,
            titleKey: "fact.title",
            bodyKey: "fact.body",
            unlockLevelID: level.id,
            source: FactSource(
                title: "Source",
                url: #require(URL(string: "https://example.com")),
                accessed: "2026-09-01"
            )
        )
    }

    private func verifiedLevel() -> CampaignLevel {
        let entityID = EntityID("guest")
        let seatID = PositionID("seat")
        let aisleID = PositionID("aisle")
        let puzzle = PuzzleDefinition(
            id: PuzzleID("test.verified"),
            entities: [PuzzleEntity(id: entityID)],
            positions: [
                PuzzlePosition(id: seatID, coordinate: GridCoordinate(row: 0, column: 0)),
                PuzzlePosition(id: aisleID, coordinate: GridCoordinate(row: 0, column: 1)),
            ],
            constraints: [.assigned(entity: entityID, position: seatID)],
            movePolicy: MovePolicy(occupiedDrop: .swap, placement: .verified, moveLimit: 4),
            starThresholds: StarThresholds(
                threeStarMaximumMoves: 1,
                twoStarMaximumMoves: 2
            )
        )
        return CampaignLevel(
            id: LevelID("test.verified"),
            countryID: CountryID("test-country"),
            cityID: CityID("test-city"),
            locationID: LocationID("test-location"),
            titleKey: "level.title",
            factID: FactID("test.fact"),
            boardStyle: .theatre,
            entityNameKeys: [entityID: "guest.name"],
            clueKeys: ["clue.one"],
            puzzle: puzzle
        )
    }

    private func testLevel() -> CampaignLevel {
        let entityID = EntityID("guest")
        let positionID = PositionID("seat")
        let puzzle = PuzzleDefinition(
            id: PuzzleID("test.level"),
            entities: [PuzzleEntity(id: entityID)],
            positions: [
                PuzzlePosition(
                    id: positionID,
                    coordinate: GridCoordinate(row: 0, column: 0)
                )
            ],
            constraints: [.assigned(entity: entityID, position: positionID)],
            movePolicy: MovePolicy(occupiedDrop: .swap),
            starThresholds: StarThresholds(
                threeStarMaximumMoves: 1,
                twoStarMaximumMoves: 2
            )
        )
        return CampaignLevel(
            id: LevelID("test.level"),
            countryID: CountryID("test-country"),
            cityID: CityID("test-city"),
            locationID: LocationID("test-location"),
            titleKey: "level.title",
            factID: FactID("test.fact"),
            boardStyle: .theatre,
            entityNameKeys: [entityID: "guest.name"],
            clueKeys: ["clue.one"],
            puzzle: puzzle
        )
    }
}

private struct StubContentRepository: ContentRepository {
    let levelValue: CampaignLevel
    let factValue: TravelFact

    init(level: CampaignLevel, fact: TravelFact) {
        levelValue = level
        factValue = fact
    }

    func levels() async throws -> [CampaignLevel] { [levelValue] }
    func level(id: LevelID) async throws -> CampaignLevel { levelValue }
    func fact(id: FactID) async throws -> TravelFact { factValue }
}

private actor RecordingProgressRepository: ProgressRepository {
    private var factID: FactID?

    func loadProgress() async throws -> JourneyProgress { JourneyProgress() }

    func recordCompletion(
        levelID: LevelID,
        result: PuzzleCompletionResult,
        factID: FactID
    ) async throws -> JourneyProgress {
        self.factID = factID
        return JourneyProgress(
            levels: [
                levelID: LevelProgress(
                    levelID: levelID,
                    isCompleted: true,
                    bestStars: result.stars,
                    bestMoveCount: result.moveCount
                )
            ],
            discoveredFactIDs: [factID]
        )
    }

    func recordedFactID() -> FactID? { factID }
}
