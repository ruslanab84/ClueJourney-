# Campaign Content Format

Campaign content is immutable JSON under the repository-level `Content/` directory. The app bundles that directory as resources; `ContentValidator` reads the same files by path. Player progress is stored separately.

## Level

Each file describes travel metadata plus one logical puzzle. The engine receives only the nested `puzzle` value.

```json
{
  "schemaVersion": 1,
  "id": "it.rome.teatro-opera.001",
  "countryID": "it",
  "cityID": "rome",
  "locationID": "teatro-opera",
  "titleKey": "level.it.rome.teatro-opera.001.title",
  "factID": "fact.it.rome.teatro-opera.001",
  "presentation": { "boardStyle": "theatre" },
  "puzzle": {
    "family": "position",
    "capabilities": ["spatialPositioning", "lockedAssignments", "swap", "undo"],
    "entities": [
      { "id": "julia", "nameKey": "character.julia" }
    ],
    "positions": [
      { "id": "seat.a1", "row": 0, "column": 0, "group": "stalls" }
    ],
    "initialAssignments": [
      { "entityID": "julia", "positionID": "seat.a1", "locked": true }
    ],
    "constraints": [
      {
        "type": "fixedAssignment",
        "subjectID": "julia",
        "positionID": "seat.a1",
        "clueKey": "clue.it.rome.teatro-opera.001.01"
      }
    ],
    "movePolicy": {
      "threeStarThreshold": 5,
      "twoStarThreshold": 7,
      "undoCountsAsMove": false,
      "occupiedDropPolicy": "swap",
      "placementPolicy": "verified",
      "moveLimit": 9
    }
  }
}
```

`placementPolicy` is `free` (any structurally legal drop is accepted; clues report their state) or `verified` (a drop that no solution can extend is refused and the character returns to the tray, while the attempt still spends a move). It defaults to `free` when absent. `moveLimit` is the authored move budget; spending it before the arrangement is complete fails the attempt. It defaults to absent, meaning an unbudgeted level.

IDs are stable, lowercase, and never derived from display text. Coordinates describe logical relationships only; artwork and pixel geometry stay in presentation. Constraint `type` values are typed engine rules. `clueKey` is display metadata, not executable logic.

## Fact

```json
{
  "schemaVersion": 1,
  "id": "fact.it.rome.teatro-opera.001",
  "locationID": "teatro-opera",
  "titleKey": "fact.it.rome.teatro-opera.001.title",
  "bodyKey": "fact.it.rome.teatro-opera.001.body",
  "unlockLevelID": "it.rome.teatro-opera.001",
  "source": {
    "title": "Editorial source title",
    "url": "https://example.org/source",
    "accessed": "2026-08-31"
  }
}
```

Facts must be durable, curated claims with source provenance. Source metadata is editorial data and need not be shown in gameplay UI.

## Validation

`ContentValidator` must reject unsupported schema versions, decode failures, duplicate or missing IDs, broken references, invalid constraints or locked assignments, missing localization keys, inconsistent star thresholds, missing fact provenance, zero solutions, and multiple solutions. A `verified` level must declare a `moveLimit`, and no `moveLimit` may fall below the level's two-star threshold or below the number of placements its single solution requires. Identical input must produce identical validation and solution order.

Run it against the authored content and base localization:

```sh
swift run --package-path Packages/PuzzlePassportKit ContentValidator \
  --content-root Content \
  --localization ClueJourney/en.lproj/Localizable.strings
```
