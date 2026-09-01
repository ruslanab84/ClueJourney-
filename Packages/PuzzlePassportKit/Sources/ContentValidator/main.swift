import Foundation
import PPData
import PPDomain
import PPGameEngine

@main
struct ContentValidator {
    static func main() async throws {
        let rootURL = try contentRoot(from: CommandLine.arguments)
        let localizationKeys = try localizationKeys(from: CommandLine.arguments)
        let repository = CampaignContentRepository(rootURL: rootURL)
        let levels = try await repository.levels()
        let facts = try await repository.facts()
        let factsByID = Dictionary(uniqueKeysWithValues: facts.map { ($0.id, $0) })
        let engine = PuzzleEngine()

        for level in levels {
            let validation = engine.validate(level.puzzle)
            guard validation.isValid else {
                throw ValidationError.invalidDefinition(level.id.rawValue, validation.issues.count)
            }
            guard level.clueKeys.count == level.puzzle.constraints.count else {
                throw ValidationError.clueCount(level.id.rawValue)
            }
            guard let fact = factsByID[level.factID], fact.unlockLevelID == level.id else {
                throw ValidationError.factReference(level.id.rawValue)
            }
            let requiredKeys = [
                level.titleKey,
                "country.\(level.countryID.rawValue).name",
                "country.\(level.countryID.rawValue).tagline",
                "country.\(level.countryID.rawValue).description",
                "country.\(level.countryID.rawValue).action",
                "city.\(level.cityID.rawValue).name",
                "city.\(level.cityID.rawValue).tagline",
                "city.\(level.cityID.rawValue).description",
                "city.\(level.cityID.rawValue).action",
                "location.\(level.locationID.rawValue).name",
                "location.\(level.locationID.rawValue).description",
                "location.\(level.locationID.rawValue).action",
                "level.\(level.id.rawValue).summary",
                "level.\(level.id.rawValue).objective",
            ] + level.entityNameKeys.values + level.clueKeys
            guard requiredKeys.allSatisfy(localizationKeys.contains) else {
                throw ValidationError.missingLocalization(level.id.rawValue)
            }
            let solutionCount = try engine.solutionCount(for: level.puzzle, limit: 2)
            guard solutionCount == 1 else {
                throw ValidationError.solutionCount(level.id.rawValue, solutionCount)
            }
            try validateMoveBudget(level, engine: engine)
        }

        for fact in facts where !localizationKeys.contains(fact.titleKey)
            || !localizationKeys.contains(fact.bodyKey)
        {
            throw ValidationError.missingLocalization(fact.id.rawValue)
        }

        print("Validated \(levels.count) level(s) and \(facts.count) fact(s).")
    }

    /// A verified level must be budgeted, and no budget may be tighter than the level's own
    /// star thresholds or than the number of placements its single solution actually requires.
    private static func validateMoveBudget(_ level: CampaignLevel, engine: PuzzleEngine) throws {
        let policy = level.puzzle.movePolicy
        guard let moveLimit = policy.moveLimit else {
            guard policy.placement == .free else {
                throw ValidationError.missingMoveLimit(level.id.rawValue)
            }
            return
        }
        guard moveLimit >= level.puzzle.starThresholds.twoStarMaximumMoves else {
            throw ValidationError.moveBudget(level.id.rawValue, moveLimit)
        }
        guard let solution = try engine.solution(for: level.puzzle) else { return }
        let initial = PuzzleArrangement(
            occupantsByPosition: Dictionary(
                uniqueKeysWithValues: level.puzzle.initialAssignments
                    .map { ($0.positionID, $0.entityID) }
            )
        )
        let requiredMoves = level.puzzle.entities.count {
            initial.position(of: $0.id) != solution.position(of: $0.id)
        }
        guard moveLimit >= requiredMoves else {
            throw ValidationError.moveBudget(level.id.rawValue, moveLimit)
        }
    }

    private static func contentRoot(from arguments: [String]) throws -> URL {
        guard
            let optionIndex = arguments.firstIndex(of: "--content-root"),
            arguments.indices.contains(optionIndex + 1)
        else {
            throw ValidationError.usage
        }
        return URL(filePath: arguments[optionIndex + 1], directoryHint: .isDirectory)
    }

    private static func localizationKeys(from arguments: [String]) throws -> Set<String> {
        guard
            let optionIndex = arguments.firstIndex(of: "--localization"),
            arguments.indices.contains(optionIndex + 1)
        else {
            throw ValidationError.usage
        }
        let url = URL(filePath: arguments[optionIndex + 1])
        let data = try Data(contentsOf: url)
        guard let values = try PropertyListSerialization.propertyList(from: data, format: nil)
            as? [String: String]
        else {
            throw ValidationError.invalidLocalizationFile
        }
        return Set(values.keys)
    }
}

private enum ValidationError: Error, CustomStringConvertible {
    case usage
    case invalidDefinition(String, Int)
    case clueCount(String)
    case factReference(String)
    case invalidLocalizationFile
    case missingLocalization(String)
    case solutionCount(String, Int)
    case missingMoveLimit(String)
    case moveBudget(String, Int)

    var description: String {
        switch self {
        case .usage:
            "Usage: ContentValidator --content-root <Content directory> --localization <Localizable.strings>"
        case .invalidDefinition(let id, let count):
            "Level \(id) has \(count) definition issue(s)."
        case .clueCount(let id):
            "Level \(id) does not provide one clue key per typed constraint."
        case .factReference(let id):
            "Level \(id) has a missing or inconsistent fact reference."
        case .invalidLocalizationFile:
            "The localization file is not a valid strings property list."
        case .missingLocalization(let id):
            "Content \(id) references a missing localization key."
        case .solutionCount(let id, let count):
            "Level \(id) has \(count) solutions; expected exactly one."
        case .missingMoveLimit(let id):
            "Level \(id) uses verified placement and must declare a moveLimit."
        case .moveBudget(let id, let limit):
            "Level \(id) has a moveLimit of \(limit) that its thresholds or solution cannot meet."
        }
    }
}
