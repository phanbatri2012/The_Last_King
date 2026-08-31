# Decision 0003 — Infinite battlefield and Phase 2 combat boundaries

## Status

Accepted for Phase 2.

## Decision

- Remove gameplay position clamping and expand `Camera2D` limits to an effectively unreachable coordinate range.
- Render a deterministic tile window around the King instead of allocating a finite world or retaining off-screen chunks.
- Use a fixed, deterministic five-Goblin drill encounter. A continuous spawn director belongs to Phase 3.
- Keep combat content in versioned King and enemy catalogs.
- Route all attacks through `DamageResolver`, with reusable `HealthComponent` nodes owning health and death signals.
- Select targets from the King's physics overlap area on a short interval, avoiding a per-frame full-world enemy scan.
- Persist only the in-memory drill snapshot required by Continue; permanent run saves remain a later slice.

## Consequences

World rendering cost stays proportional to the viewport rather than distance traveled. Combat systems can be reused by later enemies and armies without faction-specific branches. The Phase 2 drill ends after its fixed squad, making the absence of Phase 3 waves and rewards explicit.
