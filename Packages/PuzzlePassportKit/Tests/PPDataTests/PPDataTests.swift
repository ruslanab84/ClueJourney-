import Foundation
import PPApplication
import PPData
import PPDomain
import Testing

@Suite("Puzzle Passport data")
struct PPDataTests {
    @Test("Authored campaign decodes through the runtime repository")
    func authoredCampaignDecodes() async throws {
        let repository = CampaignContentRepository(rootURL: contentRoot)

        let levels = try await repository.levels()
        let facts = try await repository.facts()

        #expect(levels.count == 1)
        #expect(facts.count == 1)
        #expect(levels[0].factID == facts[0].id)
        #expect(levels[0].puzzle.movePolicy.placement == .verified)
        #expect(levels[0].puzzle.movePolicy.moveLimit == 7)
        #expect(levels[0].puzzle.entities.count == 5)
        #expect(levels[0].puzzle.positions.count == 5)
        #expect(levels[0].entityNameKeys[EntityID("elena")] == "character.elena")
        #expect(levels[0].puzzle.starThresholds.threeStarMaximumMoves == 4)
    }

    @Test("Authored easy level accepts the four correct avatar drops")
    func easyLevelAcceptsCorrectAvatarDrops() async throws {
        let contentRepository = CampaignContentRepository(rootURL: contentRoot)
        let progressRepository = try SwiftDataProgressRepository(isStoredInMemoryOnly: true)
        let journey = PuzzleJourney(
            contentRepository: contentRepository,
            progressRepository: progressRepository
        )
        let level = try #require(try await contentRepository.levels().first)
        var experience = try await journey.start(levelID: level.id)

        for (entity, position) in [
            ("tomas", "seat.back.right"),
            ("elena", "seat.front.center"),
            ("marco", "seat.front.left"),
            ("sara", "seat.front.right"),
        ] {
            let update = try await journey.apply(
                .place(entity: EntityID(entity), at: PositionID(position)),
                to: experience
            )
            #expect(update.feedback == .seated)
            experience = update.experience
        }

        guard case .completed(let result) = experience.session.status else {
            Issue.record("Expected the easy level to complete after four correct drops")
            return
        }
        #expect(result.moveCount == 4)
        #expect(result.stars == .three)
    }

    @Test("SwiftData keeps best progress and a single discovery")
    func progressKeepsPersonalBest() async throws {
        let repository = try SwiftDataProgressRepository(isStoredInMemoryOnly: true)
        let levelID = LevelID("level")
        let factID = FactID("fact")

        _ = try await repository.recordCompletion(
            levelID: levelID,
            result: PuzzleCompletionResult(moveCount: 7, stars: .one),
            factID: factID
        )
        let progress = try await repository.recordCompletion(
            levelID: levelID,
            result: PuzzleCompletionResult(moveCount: 3, stars: .three),
            factID: factID
        )

        #expect(progress.levels[levelID]?.bestMoveCount == 3)
        #expect(progress.levels[levelID]?.bestStars == .three)
        #expect(progress.discoveredFactIDs == [factID])
    }

    @Test("Unsupported fact schemas fail at the content boundary")
    func unsupportedFactSchemaFails() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let facts = root.appending(path: "Facts", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: facts, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let json = """
        {
          "schemaVersion": 99,
          "id": "fact",
          "locationID": "location",
          "titleKey": "fact.title",
          "bodyKey": "fact.body",
          "unlockLevelID": "level",
          "source": {
            "title": "Source",
            "url": "https://example.com",
            "accessed": "2026-09-01"
          }
        }
        """
        try Data(json.utf8).write(to: facts.appending(path: "fact.json"))

        let repository = CampaignContentRepository(rootURL: root)
        await #expect(throws: CampaignContentError.self) {
            try await repository.facts()
        }
    }

    private var contentRoot: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Content", directoryHint: .isDirectory)
    }
}
