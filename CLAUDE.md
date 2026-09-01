# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Clue Journey (product name "Puzzle Passport") is a SwiftUI iOS travel logic-puzzle game. All logic lives in the local SwiftPM package `Packages/PuzzlePassportKit`; the Xcode app target is only a composition root and resource host.

`AGENTS.md` holds the standing repository rules and takes precedence over anything here. `Docs/ARCHITECTURE.md`, `Docs/CONTENT_FORMAT.md`, and `Docs/adr/` explain the accepted design decisions.

## Commands

```sh
# Build / test the whole package (Swift 6 language mode, swift-tools 6.2)
swift build --package-path Packages/PuzzlePassportKit
swift test  --package-path Packages/PuzzlePassportKit

# Single test or suite (Swift Testing; --filter matches the function or type name, not the display name)
swift test --package-path Packages/PuzzlePassportKit --filter uniqueSolution
swift test --package-path Packages/PuzzlePassportKit --filter PuzzleEngineTests

# Validate authored content against the engine and localization — required after any Content/ or strings change
swift run --package-path Packages/PuzzlePassportKit ContentValidator \
  --content-root Content \
  --localization ClueJourney/en.lproj/Localizable.strings

# Build the app (single target/scheme "ClueJourney"; there is no Xcode test target)
xcodebuild -project ClueJourney.xcodeproj -scheme ClueJourney \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Standard verification order for a change: targeted test, then the package test suite, then the validator (if content or strings moved), then the app build.

## Module graph

One package, six library targets plus a validator executable. Dependencies point inward and are enforced by `Package.swift`:

```
ClueJourneyApp → PPFeatures + PPData + PPApplication
PPFeatures  → PPApplication + PPDomain + PPDesignSystem
PPData      → PPApplication + PPDomain
PPApplication → PPGameEngine + PPDomain
PPGameEngine  → PPDomain
ContentValidator → PPData + PPGameEngine + PPDomain
```

- **PPDomain** — value types only: `StableID<Tag>` phantom-typed IDs (`LevelID`, `EntityID`, `PositionID`, …), `PuzzleDefinition`, `PuzzleSession`, `PuzzleAction`, `CampaignLevel`, `TravelFact`, `JourneyProgress`. No frameworks.
- **PPGameEngine** — `PuzzleEngine`, a stateless `Sendable` struct: definition validation, arrangement validation, `apply(action:)` transitions, `solutionCount(for:limit:)`, hints, stars. Pure and deterministic; it knows nothing about travel, localization, or rendering.
- **PPApplication** — `PuzzleJourney` actor (the single use case surface: `loadJourney`, `start`, `apply`, `advance`, `evaluateClues`, `hint`, `complete`) plus the inward ports `ContentRepository` and `ProgressRepository`.
- **PPData** — `CampaignContentRepository` actor (JSON → domain, caching, sorted by ID for determinism) and `SwiftDataProgressRepository` actor (`LevelProgressRecord`, `DiscoveryRecord`). SwiftData models never escape this target.
- **PPDesignSystem** — `PPColor` / `PPSpacing` / `PPRadius` / `PPShadow` tokens with light+dark pairs, and shared views (`PPPaperBackground`, `PPPostcardCard`, `PPPrimaryButtonStyle`, `PPMetricPill`, `PPStatusBadge`, `PPRewardStars`, `PPMoveBadge`).
- **PPFeatures** — `JourneyFlowView` (the only public view) drives a `NavigationStack` over `JourneyRoute`; `JourneyFlowModel` (`@MainActor @Observable`) is the sole mutable UI state. Screens (`PassportLaunchScreen`, `PassportDestinationScreen`, `RomeOverviewScreen`, `PuzzlePreviewScreen`, `PassportPuzzleScreen`, `CompletionScreen`, `DiscoveryScreen`) are internal and stateless-ish; they emit intents and never decide correctness.
- **ClueJourney/** app target — `AppContainer.live()` builds the two repositories and the `PuzzleJourney`; `ContentView` renders `ContentUnavailableView` if bootstrap fails. No service locators or singletons.

Runtime flow: view intent → `JourneyFlowModel` → `PuzzleJourney` actor → `PuzzleEngine` (rules) and repositories (I/O) → new immutable `PuzzleExperience` → view re-renders. Completion persists progress *before* the Did You Know / discovery screen.

## Content pipeline (the part most changes touch)

Authored campaign data lives in repo-root `Content/` (`Countries/<country>/<city>/<location>/level-NNN.json`, `Facts/<country>/<city>/<location>.json`) and is bundled into the app as a **folder reference**. Adding a normal level should change JSON + strings only — never engine or SwiftUI code, and never a branch on a level ID.

Non-obvious details:

- **The JSON vocabulary is not the domain vocabulary.** Translation lives entirely in the private DTOs at the bottom of `PPData/CampaignContentRepository.swift`: `fixedAssignment` maps to `.assigned`, and `rightOf` is stored as a flipped `.leftOf`. Add new authored constraint spellings there, not in `PPDomain`.
- Levels declare `family: "position"` and a capability list; unknown families or capabilities are rejected at decode time. `schemaVersion` must be `1`.
- `movePolicy` in JSON carries both star thresholds and `undoCountsAsMove` / `occupiedDropPolicy`; the domain splits these into `StarThresholds` and `MovePolicy`.
- Facts require https source provenance and an `accessed` date in `yyyy-MM-dd`, validated at decode.
- Every level must have exactly one solution, and `clueKeys.count` must equal `constraints.count` — `ContentValidator` enforces both, plus fact back-references and the full required localization key set (country/city/location name·tagline·description·action, level summary/objective, entity names, clue keys).

## Localization

`PPFeatures` resolves strings through `ppLocalized(_:)` → `Bundle.main`, so **all** keys — including ones used only inside the package — live in the app target's `ClueJourney/en.lproj/Localizable.strings`. A key added in package code but not in that file silently renders as the raw key and, if it is a content key, fails the validator.

Clue text is presentation for a typed constraint; it is never parsed to derive a rule.

## Tests

Swift Testing (`@Suite` / `@Test` / `#expect`), no XCTest, no mocks framework. `PPDataTests` reads the real repo `Content/` directory by walking up from `#filePath`, so moving test files breaks it. `SwiftDataProgressRepository(isStoredInMemoryOnly: true)` is the seam for persistence tests. New domain or engine rules need focused tests; content-only changes need the validator.

## Design QA

`design-qa.md` records the visual-fidelity review against `DesignQA/reference.jpg`, with iteration history and per-finding fixes. Imagery in `Assets.xcassets` (`PPWelcomeHero`, `PPRomeStamp`, `PPCharacter*`, …) is original artwork; never reuse competitor assets, layouts, clue wording, or levels.

## Note

Codex (`~/.codex`) and Gemini CLI (`~/.gemini`) configs exist on this machine. Reply `/import` to scan what is importable (MCP servers, slash commands, subagents, skills, instructions), then `/import --yes=<digest>` to apply the user-level items.
