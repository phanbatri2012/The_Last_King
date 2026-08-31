# Phase 2 acceptance criteria — Infinite map and combat

Phase 2 is complete when:

1. the King can travel continuously in every direction without a gameplay boundary;
2. the camera follows without reaching the old finite arena edge, while the backdrop renders only a bounded region around the current view;
3. one data-driven Goblin enemy type is represented by a five-enemy population that continuously replaces defeated enemies;
4. Goblins pursue the King, attack in melee range, have health, and enter a defeated state at zero health;
5. the King periodically selects the nearest living enemy inside attack range and attacks automatically on cooldown;
6. both King and Goblin damage pass through `DamageResolver` and health/death behavior is owned by `HealthComponent`;
7. defeated Goblins drop bright yellow run Gold pickups, and collection passes through the shared reward grant service;
8. the localized HUD shows King HP, nearby enemies, run Gold, current target, and a retry flow after King death;
9. the desktop main menu exposes an explicit Exit Game button through the platform-adapter boundary;
10. Continue preserves King state, living enemies, pending replacements, uncollected Gold, and collected run Gold in memory;
11. automated tests cover content, spawning state, rewards, infinite coordinates, target selection, damage, death, movement, and integrated auto-attacks;
12. Windows and Web exports pass the verification pipeline and browser QA.

Escalating waves, XP, Run Level, level-up cards, and summoning remain outside Phase 2 and begin in later phases.
