import Foundation
import PPApplication
import PPDomain

public enum CampaignContentError: Error, CustomStringConvertible, Sendable {
    case missingDirectory(URL)
    case noLevels
    case duplicateLevelID(LevelID)
    case duplicateFactID(FactID)
    case levelNotFound(LevelID)
    case factNotFound(FactID)
    case invalidConstraint(String)
    case invalidReference(String)

    public var description: String {
        switch self {
        case .missingDirectory(let url): "Missing content directory: \(url.path)"
        case .noLevels: "No campaign levels were found."
        case .duplicateLevelID(let id): "Duplicate level ID: \(id)"
        case .duplicateFactID(let id): "Duplicate fact ID: \(id)"
        case .levelNotFound(let id): "Level not found: \(id)"
        case .factNotFound(let id): "Fact not found: \(id)"
        case .invalidConstraint(let value): "Invalid constraint: \(value)"
        case .invalidReference(let value): "Invalid content reference: \(value)"
        }
    }
}

public actor CampaignContentRepository: ContentRepository {
    private let rootURL: URL
    private var levelCache: [LevelID: CampaignLevel]?
    private var factCache: [FactID: TravelFact]?

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    public func levels() throws -> [CampaignLevel] {
        try loadLevels().values.sorted { $0.id < $1.id }
    }

    public func level(id: LevelID) throws -> CampaignLevel {
        guard let level = try loadLevels()[id] else {
            throw CampaignContentError.levelNotFound(id)
        }
        return level
    }

    public func fact(id: FactID) throws -> TravelFact {
        guard let fact = try loadFacts()[id] else {
            throw CampaignContentError.factNotFound(id)
        }
        return fact
    }

    public func facts() throws -> [TravelFact] {
        try loadFacts().values.sorted { $0.id < $1.id }
    }

    private func loadLevels() throws -> [LevelID: CampaignLevel] {
        if let levelCache { return levelCache }
        let directory = rootURL.appending(path: "Countries", directoryHint: .isDirectory)
        let urls = try jsonFiles(in: directory)
        var result: [LevelID: CampaignLevel] = [:]

        for url in urls {
            let dto = try JSONDecoder().decode(LevelDTO.self, from: Data(contentsOf: url))
            let level = try dto.makeDomain()
            guard result.updateValue(level, forKey: level.id) == nil else {
                throw CampaignContentError.duplicateLevelID(level.id)
            }
        }
        guard !result.isEmpty else { throw CampaignContentError.noLevels }
        levelCache = result
        return result
    }

    private func loadFacts() throws -> [FactID: TravelFact] {
        if let factCache { return factCache }
        let directory = rootURL.appending(path: "Facts", directoryHint: .isDirectory)
        let urls = try jsonFiles(in: directory)
        var result: [FactID: TravelFact] = [:]

        for url in urls {
            let dto = try JSONDecoder().decode(FactDTO.self, from: Data(contentsOf: url))
            let fact = try dto.makeDomain()
            guard result.updateValue(fact, forKey: fact.id) == nil else {
                throw CampaignContentError.duplicateFactID(fact.id)
            }
        }
        factCache = result
        return result
    }

    private func jsonFiles(in directory: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw CampaignContentError.missingDirectory(directory)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            throw CampaignContentError.missingDirectory(directory)
        }
        return enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.path < $1.path }
    }
}

private struct LevelDTO: Decodable {
    let schemaVersion: Int
    let id: String
    let countryID: String
    let cityID: String
    let locationID: String
    let titleKey: String
    let factID: String
    let presentation: PresentationDTO
    let puzzle: PuzzleDTO

    func makeDomain() throws -> CampaignLevel {
        guard schemaVersion == 1 else {
            throw CampaignContentError.invalidReference("Unsupported level schema \(schemaVersion)")
        }
        guard puzzle.family == "position" else {
            throw CampaignContentError.invalidReference("Unsupported puzzle family \(puzzle.family)")
        }
        let supportedCapabilities = Set([
            "spatialPositioning", "lockedAssignments", "swap", "undo",
        ])
        let unknownCapabilities = Set(puzzle.capabilities).subtracting(supportedCapabilities)
        guard unknownCapabilities.isEmpty else {
            throw CampaignContentError.invalidReference(
                "Unsupported capabilities: \(unknownCapabilities.sorted().joined(separator: ", "))"
            )
        }
        guard ![id, countryID, cityID, locationID, titleKey, factID].contains(where: isBlank),
              !puzzle.entities.contains(where: { isBlank($0.nameKey) }),
              !puzzle.constraints.contains(where: { isBlank($0.clueKey) })
        else {
            throw CampaignContentError.invalidReference("Level metadata must not be empty")
        }
        if let moveLimit = puzzle.movePolicy.moveLimit, moveLimit < 1 {
            throw CampaignContentError.invalidReference("moveLimit must be at least 1")
        }
        let levelID = LevelID(id)
        let entities = puzzle.entities.map { PuzzleEntity(id: EntityID($0.id)) }
        let positions = puzzle.positions.map {
            PuzzlePosition(
                id: PositionID($0.id),
                coordinate: GridCoordinate(row: $0.row, column: $0.column)
            )
        }
        let constraints = try puzzle.constraints.map { try $0.makeDomain() }
        let definition = PuzzleDefinition(
            id: PuzzleID(levelID.rawValue),
            entities: entities,
            positions: positions,
            constraints: constraints,
            initialAssignments: puzzle.initialAssignments.map {
                InitialAssignment(
                    entityID: EntityID($0.entityID),
                    positionID: PositionID($0.positionID),
                    isLocked: $0.locked
                )
            },
            movePolicy: MovePolicy(
                occupiedDrop: puzzle.movePolicy.occupiedDropPolicy,
                undoScoring: puzzle.movePolicy.undoCountsAsMove
                    ? .countsAsMove
                    : .restoresPreviousMoveCount,
                placement: puzzle.movePolicy.placementPolicy ?? .free,
                moveLimit: puzzle.movePolicy.moveLimit
            ),
            starThresholds: StarThresholds(
                threeStarMaximumMoves: puzzle.movePolicy.threeStarThreshold,
                twoStarMaximumMoves: puzzle.movePolicy.twoStarThreshold
            )
        )
        return CampaignLevel(
            id: levelID,
            countryID: CountryID(countryID),
            cityID: CityID(cityID),
            locationID: LocationID(locationID),
            titleKey: titleKey,
            factID: FactID(factID),
            boardStyle: presentation.boardStyle,
            entityNameKeys: Dictionary(
                uniqueKeysWithValues: puzzle.entities.map { (EntityID($0.id), $0.nameKey) }
            ),
            clueKeys: puzzle.constraints.map(\.clueKey),
            puzzle: definition
        )
    }
}

private struct PresentationDTO: Decodable {
    let boardStyle: PuzzleBoardStyle
}

private struct PuzzleDTO: Decodable {
    let family: String
    let capabilities: [String]
    let entities: [EntityDTO]
    let positions: [PositionDTO]
    let initialAssignments: [AssignmentDTO]
    let constraints: [ConstraintDTO]
    let movePolicy: MovePolicyDTO
}

private struct EntityDTO: Decodable {
    let id: String
    let nameKey: String
}

private struct PositionDTO: Decodable {
    let id: String
    let row: Int
    let column: Int
    let group: String?
}

private struct AssignmentDTO: Decodable {
    let entityID: String
    let positionID: String
    let locked: Bool
}

private struct ConstraintDTO: Decodable {
    enum Kind: String, Decodable {
        case assigned
        case fixedAssignment
        case excluded
        case adjacent
        case notAdjacent
        case leftOf
        case rightOf
        case immediatelyLeftOf
        case sameRow
        case differentRow
    }

    let type: Kind
    let subjectID: String
    let relatedID: String?
    let positionID: String?
    let clueKey: String

    func makeDomain() throws -> PuzzleConstraint {
        let subject = EntityID(subjectID)
        switch type {
        case .assigned, .fixedAssignment:
            return .assigned(entity: subject, position: try requiredPosition())
        case .excluded:
            return .excluded(entity: subject, position: try requiredPosition())
        case .adjacent:
            return .adjacent(subject, try requiredRelated())
        case .notAdjacent:
            return .notAdjacent(subject, try requiredRelated())
        case .leftOf:
            return .leftOf(subject, try requiredRelated())
        case .rightOf:
            return .leftOf(try requiredRelated(), subject)
        case .immediatelyLeftOf:
            return .immediatelyLeftOf(subject, try requiredRelated())
        case .sameRow:
            return .sameRow(subject, try requiredRelated())
        case .differentRow:
            return .differentRow(subject, try requiredRelated())
        }
    }

    private func requiredRelated() throws -> EntityID {
        guard let relatedID else {
            throw CampaignContentError.invalidConstraint("\(type.rawValue) requires relatedID")
        }
        return EntityID(relatedID)
    }

    private func requiredPosition() throws -> PositionID {
        guard let positionID else {
            throw CampaignContentError.invalidConstraint("\(type.rawValue) requires positionID")
        }
        return PositionID(positionID)
    }
}

private struct MovePolicyDTO: Decodable {
    let threeStarThreshold: Int
    let twoStarThreshold: Int
    let undoCountsAsMove: Bool
    let occupiedDropPolicy: OccupiedDropPolicy
    /// Absent means the historical behaviour: any structurally legal placement is accepted.
    let placementPolicy: PlacementPolicy?
    /// Absent means an unbudgeted level.
    let moveLimit: Int?
}

private struct FactDTO: Decodable {
    let schemaVersion: Int
    let id: String
    let locationID: String
    let titleKey: String
    let bodyKey: String
    let unlockLevelID: String
    let source: FactSourceDTO

    func makeDomain() throws -> TravelFact {
        guard schemaVersion == 1 else {
            throw CampaignContentError.invalidReference("Unsupported fact schema \(schemaVersion)")
        }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.isLenient = false
        guard ![id, locationID, titleKey, bodyKey, unlockLevelID, source.title].contains(where: isBlank),
              source.url.scheme == "https",
              source.url.host() != nil,
              dateFormatter.date(from: source.accessed) != nil
        else {
            throw CampaignContentError.invalidReference("Fact metadata or provenance is invalid")
        }
        return TravelFact(
            id: FactID(id),
            locationID: LocationID(locationID),
            titleKey: titleKey,
            bodyKey: bodyKey,
            unlockLevelID: LevelID(unlockLevelID),
            source: source.makeDomain()
        )
    }
}

private func isBlank(_ value: String) -> Bool {
    value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

private struct FactSourceDTO: Decodable {
    let title: String
    let url: URL
    let accessed: String

    func makeDomain() -> FactSource {
        FactSource(title: title, url: url, accessed: accessed)
    }
}
