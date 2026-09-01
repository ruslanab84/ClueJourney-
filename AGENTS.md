# Repository Agent Rules

These rules apply to every automated change in this repository.

- Change only files required by the approved task. Preserve unrelated work and avoid opportunistic refactors.
- Read the affected module, its callers, and its tests before editing.
- `PPDomain` must not import SwiftUI, SwiftData, StoreKit, CloudKit, GameKit, FoundationModels, analytics, or advertising SDKs.
- `PPGameEngine` may depend only on `PPDomain`; it must stay deterministic and independent of UI, persistence, travel metadata, localization, and animations.
- SwiftUI renders state and emits intents. Puzzle rules, move counting, completion, progression, and persistence do not belong in views.
- Campaign JSON under `Content/` is the only authored level/fact source. Do not duplicate it in Swift or branch on level IDs in UI code.
- Do not add or update third-party dependencies without explicit approval.
- Do not introduce global service locators or `Service.shared`; use explicit dependency injection at the app composition root.
- New domain rules require focused tests. Content changes require the content validator.
- Run targeted tests first, then relevant package tests and an app build. Report the exact commands and any failures.
- Never copy competitor assets, layouts, clue wording, levels, or game data.
