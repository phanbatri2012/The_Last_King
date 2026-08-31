# Phase 2 acceptance criteria — Infinite map and combat

This document records the completed Phase 2 baseline. The active population and single-archetype criteria were superseded by the bounded endless multi-archetype system in `phase-3.md`.

Phase 2 is complete when:

1. the King can travel continuously in every direction without a gameplay boundary;
2. the camera follows without reaching the old finite arena edge, while the backdrop renders only a bounded region around the current view;
3. one data-driven Goblin enemy type is represented by a five-enemy population that continuously replaces defeated enemies;
4. Goblins pursue the King, attack in melee range, have health, and enter a defeated state at zero health;
5. the King periodically selects the nearest living enemy inside attack range and attacks automatically on cooldown;
6. the King has a cyan-and-gold health bar above the crown, distinct from the red enemy health bars;
7. weapon archetypes enforce higher sword/blade damage bands and longer bow/crossbow range bands, while each King owns an individual attack range;
8. both King and Goblin damage pass through `DamageResolver` and health/death behavior is owned by `HealthComponent`;
9. defeated Goblins drop bright yellow run Gold pickups, and collection passes through the shared reward grant service;
10. the localized HUD shows King HP, nearby enemies, run Gold, current target, and a retry flow after King death;
11. the desktop main menu exposes an explicit Exit Game button through the platform-adapter boundary;
12. Continue preserves King state, living enemies, pending replacements, uncollected Gold, and collected run Gold in memory;
13. automated tests cover content, weapon balance, spawning state, rewards, infinite coordinates, target selection, damage, death, movement, and integrated auto-attacks;
14. Windows and Web exports pass the verification pipeline and browser QA.

Escalating waves, XP, Run Level, level-up cards, and summoning remain outside Phase 2 and begin in later phases.
