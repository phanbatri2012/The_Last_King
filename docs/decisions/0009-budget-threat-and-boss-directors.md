# Decision 0009 — Budget Threat Director and Boss Director

## Status

Accepted.

## Decision

Goblin escalation uses two ordinary battle-owned directors. `EnemySpawnDirector` receives a seeded spawn budget every 15 seconds, selects only enemy IDs unlocked by the current data-driven phase, limits special/support spending, and schedules actor creation up to the platform hard cap. Time-based HP, damage, and capped speed multipliers are attached to each spawn request and saved with the enemy snapshot. Once the soft cap is reached, the Director favors elite/ascendant quality instead of depending on ever-higher actor counts.

`BossDirector` owns the timed twelve-Boss ladder, pre-Boss pressure reduction, post-death relief, seeded Ascendant cycles, and its saveable scheduling state. Boss actors remain ordinary `BossController` nodes. Every Boss has one data-driven signature ID with a visible telegraph, an execution state, a recovery window, enhanced parameters below the configured HP threshold, and a Stagger vulnerability meter. Signature and basic damage still pass through `DamageResolver`; rewards still pass through `RewardGrantService`.

The original stable enemy ID `goblin` remains the Basic Goblin rather than being renamed to `goblin_basic`. Existing `goblin_brute`, `goblin_archer`, and `goblin_hexer` IDs are also retained. All new enemy and Boss content is selected through data, not faction- or ID-specific branches in the arena.

Platform caps follow the Phase 6 design data: Web/YouTube 180 soft and 220 hard; Android/iOS 220 soft and 280 hard; desktop stress runtime 300 soft and 400 hard. The opening phase intentionally starts at eight weak Basic Goblins for readability, then increases quantity, unlocked roles, elite density, stat pressure, and Boss complexity over time.
