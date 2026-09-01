# Content data

Content is loaded and validated independently from gameplay systems. Stable IDs use lowercase `snake_case`.

The Phase 0 roster is planning metadata, not production-ready historical research. Entries marked `planned_cultural_review` require additional cultural and historical review before implementation.

- `factions/faction_roster.json`: open-ended faction planning roster.
- `kings/kings.json`: versioned King movement, health, defense, summon policy, and attack data. The current slice contains Trần Hưng Đạo only.
- `combat/weapon_archetypes.json`: shared balance bands for sword, blade, bow, and crossbow Kings. Melee bands guarantee higher damage; ranged bands guarantee longer reach while preserving per-King range values.
- `enemies/enemies.json`: versioned enemy role, health, defense, movement, hatred range, dodgeable projectile, presentation, weighted spawn, Gold, XP, and Healing Orb data. The active roster contains Raider, Brute, Archer, and Hexer Goblins.
- `units/units.json`: summon cost, hotkey, combat, projectile, run-Gold upgrade curve, role-specific formation, and presentation data for seven Đại Việt units.
- `skills/king_skills.json`: King XP curve and six three-rank, data-driven passive/automatic combat skills.
- `schemas/`: validation contracts for content tooling.
