# ADR 0001: Module Boundaries

- Status: Accepted

## Context

The game needs isolated, testable puzzle logic without multiplying packages or ceremonial protocols.

## Decision

Use one local Swift package with focused targets: `PPDomain`, `PPGameEngine`, `PPApplication`, `PPData`, `PPDesignSystem`, and `PPFeatures`. The Xcode app target is the composition root. SwiftPM dependencies enforce the inward graph documented in `ARCHITECTURE.md`. Repository-level `Content/` remains the single campaign source consumed through `PPData`.

Create ports only for replaceable persistence, content, commerce, ads, cloud, analytics, audio/haptics, or other external I/O. Do not create `PPInfrastructure` or SDK targets until a real adapter is implemented.

## Consequences

Domain and engine tests run without SwiftUI or SwiftData. Features cannot instantiate persistence or SDK objects. A target may be split into another package only when compile-time ownership or dependency pressure justifies it.
