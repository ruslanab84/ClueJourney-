import PPApplication
import PPDomain
import SwiftData

@Model
public final class LevelProgressRecord {
    @Attribute(.unique) public var levelID: String
    public var isCompleted: Bool
    public var bestStars: Int
    public var bestMoveCount: Int

    public init(
        levelID: String,
        isCompleted: Bool,
        bestStars: Int,
        bestMoveCount: Int
    ) {
        self.levelID = levelID
        self.isCompleted = isCompleted
        self.bestStars = bestStars
        self.bestMoveCount = bestMoveCount
    }
}

@Model
public final class DiscoveryRecord {
    @Attribute(.unique) public var factID: String

    public init(factID: String) {
        self.factID = factID
    }
}

public actor SwiftDataProgressRepository: ProgressRepository {
    private let container: ModelContainer

    public init(isStoredInMemoryOnly: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isStoredInMemoryOnly)
        container = try ModelContainer(
            for: LevelProgressRecord.self,
            DiscoveryRecord.self,
            configurations: configuration
        )
    }

    public func loadProgress() throws -> JourneyProgress {
        let context = ModelContext(container)
        let levelRecords = try context.fetch(FetchDescriptor<LevelProgressRecord>())
        let discoveries = try context.fetch(FetchDescriptor<DiscoveryRecord>())
        let levels = Dictionary(
            uniqueKeysWithValues: levelRecords.map { record in
                let levelID = LevelID(record.levelID)
                return (
                    levelID,
                    LevelProgress(
                        levelID: levelID,
                        isCompleted: record.isCompleted,
                        bestStars: StarRating(rawValue: record.bestStars) ?? .one,
                        bestMoveCount: record.bestMoveCount
                    )
                )
            }
        )
        return JourneyProgress(
            levels: levels,
            discoveredFactIDs: Set(discoveries.map { FactID($0.factID) })
        )
    }

    public func recordCompletion(
        levelID: LevelID,
        result: PuzzleCompletionResult,
        factID: FactID
    ) throws -> JourneyProgress {
        let context = ModelContext(container)
        // ponytail: v1 progress is tiny; use indexed predicates if campaign-scale profiling needs it.
        let levelRecords = try context.fetch(FetchDescriptor<LevelProgressRecord>())
        if let record = levelRecords.first(where: { $0.levelID == levelID.rawValue }) {
            record.isCompleted = true
            record.bestStars = max(record.bestStars, result.stars.rawValue)
            record.bestMoveCount = min(record.bestMoveCount, result.moveCount)
        } else {
            context.insert(
                LevelProgressRecord(
                    levelID: levelID.rawValue,
                    isCompleted: true,
                    bestStars: result.stars.rawValue,
                    bestMoveCount: result.moveCount
                )
            )
        }

        let discoveries = try context.fetch(FetchDescriptor<DiscoveryRecord>())
        if !discoveries.contains(where: { $0.factID == factID.rawValue }) {
            context.insert(DiscoveryRecord(factID: factID.rawValue))
        }
        try context.save()
        return try loadProgress()
    }
}
