import Foundation

public enum LevelIDTag: Sendable {}
public enum CountryIDTag: Sendable {}
public enum CityIDTag: Sendable {}
public enum LocationIDTag: Sendable {}
public enum FactIDTag: Sendable {}

public typealias LevelID = StableID<LevelIDTag>
public typealias CountryID = StableID<CountryIDTag>
public typealias CityID = StableID<CityIDTag>
public typealias LocationID = StableID<LocationIDTag>
public typealias FactID = StableID<FactIDTag>

public enum PuzzleBoardStyle: String, Hashable, Codable, Sendable {
    case theatre
    case standing
    case aircraft
    case restaurant
    case route
    case grouping
}

public struct CampaignLevel: Hashable, Codable, Sendable {
    public let id: LevelID
    public let countryID: CountryID
    public let cityID: CityID
    public let locationID: LocationID
    public let titleKey: String
    public let factID: FactID
    public let boardStyle: PuzzleBoardStyle
    public let entityNameKeys: [EntityID: String]
    public let clueKeys: [String]
    public let puzzle: PuzzleDefinition

    public init(
        id: LevelID,
        countryID: CountryID,
        cityID: CityID,
        locationID: LocationID,
        titleKey: String,
        factID: FactID,
        boardStyle: PuzzleBoardStyle,
        entityNameKeys: [EntityID: String],
        clueKeys: [String],
        puzzle: PuzzleDefinition
    ) {
        self.id = id
        self.countryID = countryID
        self.cityID = cityID
        self.locationID = locationID
        self.titleKey = titleKey
        self.factID = factID
        self.boardStyle = boardStyle
        self.entityNameKeys = entityNameKeys
        self.clueKeys = clueKeys
        self.puzzle = puzzle
    }
}

public struct FactSource: Hashable, Codable, Sendable {
    public let title: String
    public let url: URL
    public let accessed: String

    public init(title: String, url: URL, accessed: String) {
        self.title = title
        self.url = url
        self.accessed = accessed
    }
}

public struct TravelFact: Identifiable, Hashable, Codable, Sendable {
    public let id: FactID
    public let locationID: LocationID
    public let titleKey: String
    public let bodyKey: String
    public let unlockLevelID: LevelID
    public let source: FactSource

    public init(
        id: FactID,
        locationID: LocationID,
        titleKey: String,
        bodyKey: String,
        unlockLevelID: LevelID,
        source: FactSource
    ) {
        self.id = id
        self.locationID = locationID
        self.titleKey = titleKey
        self.bodyKey = bodyKey
        self.unlockLevelID = unlockLevelID
        self.source = source
    }
}

public struct LevelProgress: Hashable, Codable, Sendable {
    public let levelID: LevelID
    public let isCompleted: Bool
    public let bestStars: StarRating
    public let bestMoveCount: Int

    public init(
        levelID: LevelID,
        isCompleted: Bool,
        bestStars: StarRating,
        bestMoveCount: Int
    ) {
        self.levelID = levelID
        self.isCompleted = isCompleted
        self.bestStars = bestStars
        self.bestMoveCount = bestMoveCount
    }
}

public struct JourneyProgress: Hashable, Codable, Sendable {
    public let levels: [LevelID: LevelProgress]
    public let discoveredFactIDs: Set<FactID>

    public init(
        levels: [LevelID: LevelProgress] = [:],
        discoveredFactIDs: Set<FactID> = []
    ) {
        self.levels = levels
        self.discoveredFactIDs = discoveredFactIDs
    }
}
