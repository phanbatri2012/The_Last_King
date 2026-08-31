# Phase 2 acceptance criteria — Infinite map and combat

Phase 2 is complete when:

1. the King can travel continuously in every direction without a gameplay boundary;
2. the camera follows without reaching the old finite arena edge, while the backdrop renders only a bounded region around the current view;
3. one data-driven Goblin enemy type is represented by a fixed five-enemy combat-drill squad;
4. Goblins pursue the King, attack in melee range, have health, and enter a defeated state at zero health;
5. the King periodically selects the nearest living enemy inside attack range and attacks automatically on cooldown;
6. both King and Goblin damage pass through `DamageResolver` and health/death behavior is owned by `HealthComponent`;
7. the localized HUD shows King HP, remaining enemies, current target, and a retry flow after King death;
8. Continue preserves the King position/health and the fixed encounter's living/defeated state in memory;
9. automated tests cover content, infinite coordinates, target selection, damage, death, movement, and an integrated auto-attack;
10. Windows and Web exports pass the verification pipeline and browser QA.

Continuous enemy spawning, XP, Run Level, level-up cards, rewards, and summoning remain outside Phase 2 and begin in later phases.
