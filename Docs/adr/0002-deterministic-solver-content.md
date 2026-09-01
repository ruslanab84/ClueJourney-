# ADR 0002: Deterministic Solver and Content

- Status: Accepted

## Context

Campaign puzzles must remain correct, testable, and reusable across travel locations and presentation styles.

## Decision

Represent puzzle rules as typed constraints and evaluate them with one deterministic engine. Human-readable clues are localized presentation. Campaign levels and facts are bundled JSON; SwiftUI contains no level-specific behavior.

Every standard campaign level passes domain validation, reference validation, solution counting, and an exactly-one-solution check before shipping. Hints derive from valid solver state. Facts are curated content with provenance and unlock independently of screen presentation.

## Consequences

Adding a normal level changes content, not engine or UI code. Unsupported constraints fail validation instead of silently degrading. Solver changes require focused determinism, zero/one/multiple-solution, move, undo, hint, and performance checks.
