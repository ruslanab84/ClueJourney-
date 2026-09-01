import Observation
import PPApplication
import PPDomain
import SwiftUI

public enum JourneyRoute: Hashable {
    case country(CountryID)
    case city(CityID)
    case location(LocationID)
    case puzzle(LevelID)
    case completion(LevelID)
    case discovery(FactID)
}

@MainActor
@Observable
public final class JourneyFlowModel {
    public private(set) var snapshot: JourneySnapshot?
    public private(set) var experience: PuzzleExperience?
    public private(set) var clueEvaluations: [ConstraintEvaluation] = []
    public private(set) var completion: CompletionOutcome?
    public private(set) var hintedEntityID: EntityID?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public var selectedEntityID: EntityID?

    private let journey: PuzzleJourney

    public init(journey: PuzzleJourney) {
        self.journey = journey
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            snapshot = try await journey.loadJourney()
            errorMessage = nil
        } catch {
            errorMessage = ppLocalized("error.content.load")
        }
    }

    public func start(levelID: LevelID) async -> Bool {
        do {
            let experience = try await journey.start(levelID: levelID)
            self.experience = experience
            clueEvaluations = await journey.evaluateClues(in: experience)
            completion = nil
            selectedEntityID = nil
            hintedEntityID = nil
            errorMessage = nil
            return true
        } catch {
            errorMessage = ppLocalized("error.puzzle.start")
            return false
        }
    }

    public func select(_ entityID: EntityID) {
        guard let experience, !isLocked(entityID, in: experience.level) else { return }
        selectedEntityID = selectedEntityID == entityID ? nil : entityID
    }

    public func tap(positionID: PositionID) async -> Bool {
        guard let experience else { return false }
        if let selectedEntityID {
            return await place(entityID: selectedEntityID, at: positionID)
        }
        guard let occupant = experience.session.arrangement.entity(at: positionID) else {
            return false
        }
        select(occupant)
        return false
    }

    public func place(entityID: EntityID, at positionID: PositionID) async -> Bool {
        guard let experience else { return false }
        do {
            let update = try await journey.advance(
                .place(entity: entityID, at: positionID),
                from: experience
            )
            let updated = update.experience
            self.experience = updated
            clueEvaluations = await journey.evaluateClues(in: updated)
            selectedEntityID = nil
            hintedEntityID = nil
            errorMessage = nil

            guard let outcome = update.completion, completion == nil else {
                return false
            }
            completion = outcome
            if let snapshot {
                self.snapshot = JourneySnapshot(levels: snapshot.levels, progress: outcome.progress)
            }
            return true
        } catch {
            errorMessage = ppLocalized("error.puzzle.action")
            return false
        }
    }

    public func undo() async {
        await applyNonCompleting(.undo)
    }

    public func restart() async {
        completion = nil
        selectedEntityID = nil
        hintedEntityID = nil
        await applyNonCompleting(.restart)
    }

    public func requestHint() async {
        guard let experience else { return }
        do {
            guard case .forcedPlacement(let entityID, _) = try await journey.hint(for: experience)
            else { return }
            hintedEntityID = entityID
            selectedEntityID = entityID
        } catch {
            errorMessage = ppLocalized("error.puzzle.hint")
        }
    }

    public func isLocked(_ entityID: EntityID, in level: CampaignLevel) -> Bool {
        level.puzzle.initialAssignments.contains {
            $0.entityID == entityID && $0.isLocked
        }
    }

    public func isLocked(_ positionID: PositionID, in level: CampaignLevel) -> Bool {
        level.puzzle.initialAssignments.contains {
            $0.positionID == positionID && $0.isLocked
        }
    }

    public func clearError() {
        errorMessage = nil
    }

    private func applyNonCompleting(_ action: PuzzleAction) async {
        guard let experience else { return }
        do {
            let updated = try await journey.apply(action, to: experience)
            self.experience = updated
            clueEvaluations = await journey.evaluateClues(in: updated)
            errorMessage = nil
        } catch {
            errorMessage = ppLocalized("error.puzzle.action")
        }
    }
}

public struct JourneyFlowView: View {
    @State private var model: JourneyFlowModel
    @State private var path: [JourneyRoute] = []

    public init(journey: PuzzleJourney) {
        _model = State(initialValue: JourneyFlowModel(journey: journey))
    }

    public var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let level = model.snapshot?.levels.first {
                    JourneyScreen(
                        level: level,
                        progress: model.snapshot?.progress.levels[level.id],
                        onOpen: { path.append(.country(level.countryID)) }
                    )
                } else if model.isLoading {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    ContentUnavailableView(
                        ppLocalized("error.content.title"),
                        systemImage: "map",
                        description: Text(model.errorMessage ?? ppLocalized("error.content.load"))
                    )
                }
            }
            .navigationDestination(for: JourneyRoute.self) { route in
                destination(for: route)
            }
        }
        .task { await model.load() }
        .alert(
            ppLocalized("error.title"),
            isPresented: Binding(
                get: { model.snapshot != nil && model.errorMessage != nil },
                set: { if !$0 { model.clearError() } }
            )
        ) {
            Button(ppLocalized("error.dismiss")) { model.clearError() }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func destination(for route: JourneyRoute) -> some View {
        if let level = model.snapshot?.levels.first {
            switch route {
            case .country:
                CountryScreen(level: level) {
                    path.append(.city(level.cityID))
                }
            case .city:
                CityScreen(
                    level: level,
                    progress: model.snapshot?.progress.levels[level.id]
                ) {
                    path.append(.location(level.locationID))
                }
            case .location:
                VenueScreen(level: level) {
                    Task {
                        if await model.start(levelID: level.id) {
                            path.append(.puzzle(level.id))
                        }
                    }
                }
            case .puzzle:
                PuzzleScreen(model: model) {
                    path.append(.completion(level.id))
                }
            case .completion:
                if let completion = model.completion {
                    CompletionScreen(outcome: completion) {
                        path.append(.discovery(completion.fact.id))
                    }
                }
            case .discovery:
                if let completion = model.completion {
                    DiscoveryScreen(fact: completion.fact) {
                        path = [.country(level.countryID), .city(level.cityID)]
                    }
                }
            }
        }
    }
}

func ppLocalized(_ key: String) -> String {
    String(localized: String.LocalizationValue(key), bundle: .main)
}
