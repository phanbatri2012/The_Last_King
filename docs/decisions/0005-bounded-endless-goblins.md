# Decision 0005 — Bounded endless Goblin population

## Status

Accepted.

## Decision

The encounter has unlimited lifetime spawns but a bounded simultaneous population. It begins at 9 active or pending Goblins, adds one population slot every 45 seconds, and caps at 15. Defeated Goblins schedule replacements indefinitely. Goblins farther than 1,700 world units from the King are retired without granting rewards and replaced near the travelling King.

Enemy archetypes are selected by the seeded gameplay RNG using weights from the enemy catalog. This keeps replay and Continue behavior deterministic while avoiding wall-clock combat decisions.

Every Goblin owns data-driven health, armor, magic resistance, movement speed, collision radius, hatred range, attack style, damage type, damage, attack range, attacks per second, presentation, spawn weight, and run Gold reward. Engine code does not branch on a specific Goblin ID.

Goblins begin idle. They become permanently engaged for their current lifetime when the King enters their individual hatred range or when damage context identifies the King as the source. All outgoing damage still passes through `DamageResolver`; armor handles physical damage and magic resistance handles magic damage.

## Consequences

- Runs can continue without exhausting an encounter roster.
- Web and low-end mobile workloads remain predictable.
- New Goblin types can be added through content data when existing attack styles and damage types are sufficient.
- Off-screen recycling cannot be farmed because it grants no Gold and does not emit a defeat event.
