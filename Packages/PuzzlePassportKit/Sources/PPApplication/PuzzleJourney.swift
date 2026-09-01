import PPDomain
import PPGameEngine

public protocol ContentRepository: Sendable {
    func levels() async throws -> [CampaignLevel]
    func level(id: LevelID) async throws -> CampaignLevel
    func fact(id: FactID) async throws -> TravelFact
}

public protocol ProgressRepository: Sendable {
    func loadProgress() async throws -> JourneyProgress
    func recordCompletion(
        levelID: LevelID,
        result: PuzzleCompletionResult,
        factID: FactID
    ) async throws -> JourneyProgress
}

public struct JourneySnapshot: Sendable {
    public let levels: [CampaignLevel]
    public let progress: JourneyProgress

    public init(levels: [CampaignLevel], progress: JourneyProgress) {
        self.levels = levels
        self.progress = progress
    }
}

public struct PuzzleExperience: Sendable {
    public let level: CampaignLevel
    public let session: PuzzleSession

    public init(level: CampaignLevel, session: PuzzleSession) {
        self.level = level
        self.session = session
    }
}

public struct CompletionOutcome: Sendable {
    public let result: PuzzleCompletionResult
    public let fact: TravelFact
    public let progress: JourneyProgress

    public init(
        result: PuzzleCompletionResult,
        fact: TravelFact,
        progress: JourneyProgress
    ) {
        self.result = result
        self.fact = fact
        self.progress = progress
    }
}

public enum PuzzleJourneyError: Error, Sendable {
    case puzzleNotCompleted
    case puzzleIDMismatch
}

public actor PuzzleJourney {
    private let contentRepository: any ContentRepository
    private let progressRepository: any ProgressRepository
    private let engine: PuzzleEngine

    public init(
        contentRepository: any ContentRepository,
        progressRepository: any ProgressRepository,
        engine: PuzzleEngine = PuzzleEngine()
    ) {
        self.contentRepository = contentRepository
        self.progressRepository = progressRepository
        self.engine = engine
    }

    public func loadJourney() async throws -> JourneySnapshot {
        async let levels = contentRepository.levels()
        async let progress = progressRepository.loadProgress()
        return try await JourneySnapshot(levels: levels, progress: progress)
    }

    public func start(levelID: LevelID) async throws -> PuzzleExperience {
        let level = try await contentRepository.level(id: levelID)
        let session = try engine.start(level.puzzle)
        return PuzzleExperience(level: level, session: session)
    }

    public func apply(
        _ action: PuzzleAction,
        to experience: PuzzleExperience
    ) throws -> PuzzleExperience {
        let transition = try engine.apply(
            action,
            to: experience.session,
            in: experience.level.puzzle
        )
        return PuzzleExperience(level: experience.level, session: transition.session)
    }

    public func advance(
        _ action: PuzzleAction,
        from experience: PuzzleExperience
    ) async throws -> (experience: PuzzleExperience, completion: CompletionOutcome?) {
        let updated = try apply(action, to: experience)
        guard case .completed = updated.session.status else {
            return (updated, nil)
        }
        return (updated, try await complete(updated))
    }

    public func evaluateClues(in experience: PuzzleExperience) -> [ConstraintEvaluation] {
        engine.validate(
            experience.session.arrangement,
            for: experience.level.puzzle
        ).constraintEvaluations
    }

    public func hint(for experience: PuzzleExperience) throws -> PuzzleHint? {
        try engine.hint(for: experience.session, in: experience.level.puzzle)
    }

    public func complete(_ experience: PuzzleExperience) async throws -> CompletionOutcome {
        guard experience.session.puzzleID == experience.level.puzzle.id else {
            throw PuzzleJourneyError.puzzleIDMismatch
        }
        guard case .completed(let result) = experience.session.status else {
            throw PuzzleJourneyError.puzzleNotCompleted
        }

        let fact = try await contentRepository.fact(id: experience.level.factID)
        let progress = try await progressRepository.recordCompletion(
            levelID: experience.level.id,
            result: result,
            factID: fact.id
        )
        return CompletionOutcome(result: result, fact: fact, progress: progress)
    }
}
