# The Last King — Codex Rules

## Product baseline

- Build one gameplay core for desktop/web, YouTube Playables, Android, and iOS.
- Godot Standard + GDScript is the canonical implementation.
- English (US) is canonical and fallback; Vietnamese is supported from the start.
- Historical leaders and armies must respect their selected era. Fantasy is allowed in enemies, powers, and clearly framed adaptations.
- The faction roster is open-ended. Both the United States entry and Persia are retained; there is no fixed limit of 20 factions.

## Architecture

- Gameplay code must never call YouTube, Google Play, Apple, ad, or billing APIs directly.
- Platform-specific behavior belongs behind `PlatformAdapter` and capability checks.
- Global autoloads are services only. Units, enemies, bosses, projectiles, and battle state are ordinary objects/nodes.
- New content should be data-driven when it can use existing systems.
- Never scatter faction checks such as `if faction_id == "dai_viet"` through engine code.
- All damage must eventually pass through one resolver; all rewards through one grant service; all pause reasons through one pause manager.
- Use seeded gameplay RNG. Do not use wall-clock time for combat simulation.

## Data and localization

- Stable IDs use lowercase `snake_case` and must not change after release.
- User-facing strings must use localization keys. Do not hard-code display text in gameplay or UI scripts.
- Keep `run_gold` (temporary summon currency) separate from `account_gold` (persistent progression currency).
- Every save includes `schema_version`; migrations are required when the schema changes.
- Validate content data at startup and in automated tests.

## Delivery discipline

- Implement one playable vertical slice at a time.
- At the end of every phase, the project must launch, run without errors, retain previous behavior, and pass existing tests.
- Prefer small cohesive classes. Do not create a monolithic manager.
- Do not replace a working subsystem with a large untested rewrite.
- Preserve unrelated user changes in a dirty worktree.

## Performance baseline

- Design for Web/low-end mobile first using the Compatibility renderer.
- Pool high-frequency objects and avoid per-frame full-world scans.
- Keep YouTube Playables limits visible during development: startup payload, per-file size, save size, and memory must be measured from early exports.
