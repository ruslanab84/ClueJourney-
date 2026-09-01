# ADR 0003: Verified Placement and Move Budgets

- Status: Accepted

## Context

The first slice accepted any structurally legal placement and reported clue state afterwards, so a player could arrange the board by trial and error without reading a clue. Playtesting against the reference genre showed the loop the campaign wants: a drop is a committed guess, a wrong guess is refused and costs something, and an attempt can run out.

## Decision

`MovePolicy` carries two authored knobs. `placementPolicy` selects `free` (the previous behaviour) or `verified`. Under `verified`, `PuzzleEngine` refuses a placement that its existing solver cannot extend to a solution: the arrangement and history are untouched, the attempt spends a move, and the outcome reports `contradictsClues`. `moveLimit` is the authored budget; an incomplete arrangement that has spent it becomes `PuzzleSessionStatus.failed`, and a failed session refuses further placements.

Structural rejections — unknown entity or seat, locked entity, locked seat, occupied seat under the `reject` policy — remain free. `PuzzleJourney` maps engine outcomes to a `PlacementFeedback` value so presentation can react without importing `PPGameEngine`.

## Consequences

Levels choose their own rules in content; the engine and the views stay level-agnostic. `ContentValidator` rejects a verified level with no budget, and any budget below the level's two-star threshold or below the placements its single solution requires. Undo cannot honestly refund a refused move, so presentation hides it on budgeted levels; a restart is the way back. Solver work now runs once per drop on verified levels, which is negligible at campaign size and is the first thing to memoize if a level ever grows past a handful of entities.
