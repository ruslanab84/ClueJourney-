# Clue Journey Architecture

Clue Journey uses Clean Architecture with feature-oriented SwiftUI presentation. Dependencies point inward; the app target is the only composition root.

`A → B` means “A depends on B.”

```text
ClueJourneyApp → PPFeatures + PPData + PPApplication
PPFeatures → PPApplication + PPDomain + PPDesignSystem
PPData → PPApplication + PPDomain
PPApplication → PPGameEngine + PPDomain
PPGameEngine → PPDomain
ContentValidator → PPData + PPGameEngine
```

## Boundaries

- `PPDomain`: stable IDs, value types, constraints, progress, facts, and invariants. No Apple UI, persistence, commerce, cloud, analytics, or AI frameworks.
- `PPGameEngine`: deterministic validation, solving, solution counting, hints, move history, undo, and stars. It knows neither travel locations nor rendering.
- `PPApplication`: use-case orchestration and inward-facing repository/service ports.
- `PPData`: JSON decoding/mapping and SwiftData repository implementations. The app passes the bundled `Content/` root URL; the validator passes a filesystem URL.
- `PPDesignSystem`: semantic visual tokens and genuinely reusable SwiftUI components.
- `PPFeatures`: Journey, Destination, Puzzle, Completion, and Discovery presentation. Views emit intents and never decide puzzle correctness.
- `ClueJourneyApp`: dependency construction, typed navigation, and resource wiring.

Ports exist only for replaceable I/O or SDK boundaries. Do not create one-method wrappers around cohesive in-process behavior.

## Sources of truth

1. The explicit approved task defines change scope. These standing constraints apply unless the user explicitly changes them.
2. Typed domain constraints and engine state determine puzzle behavior and completion.
3. `Content/` JSON is the only authored source for campaign levels and travel facts.
4. Localized clue text presents a typed constraint; it is never parsed as a rule.
5. SwiftData stores player progress only. Persisted models never leak into domain or SwiftUI.
6. Facts are curated and retain editorial provenance. Generated text is never authoritative.
7. Approved mockups define visual language only; production assets, layouts, clues, and levels must be independently authored.

## First vertical slice

```text
Journey → Italy → Rome → Roman Theatre → Puzzle
        → Completion → Did You Know → progress saved
```

The first slice contains one data-driven Theatre level. Locked characters cannot move or be displaced; movable characters may place or swap according to `MovePolicy`. Cancelled, structurally impossible, and same-position drops do not count as moves. Under the authored `verified` placement policy a drop that no solution can extend is refused — the board does not change, but the attempt spends a move, and spending the authored `moveLimit` before the arrangement is complete fails the attempt. Undo restores the previous arrangement and restart restores authored state; presentation hides undo on budgeted levels because a refused move cannot be refunded. Completion and clue feedback come from `PPGameEngine`.

Drag must have an accessible tap-to-place alternative. Discovery and level progress are saved before the Did You Know screen is presented. Do not add other countries, stores, SDK adapters, or puzzle families until this path is green and the shared engine boundary is proven.
