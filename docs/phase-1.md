# Phase 1 acceptance criteria — Movement

Phase 1 is complete when:

1. Start Movement Drill launches a playable empty arena as Trần Hưng Đạo;
2. WASD and Arrow Keys move the King with normalized diagonal speed;
3. a pointer/touch virtual joystick provides analog movement;
4. the camera follows smoothly and never reveals space beyond the arena;
5. the King cannot move beyond the arena bounds;
6. the HUD remains usable at the 16:9 desktop/Web baseline and touch sizes;
7. returning to the menu preserves the in-memory position and Continue restores it;
8. King movement data and all visible strings are versioned and localized;
9. automated tests cover movement, joystick math, bounds, and session snapshots;
10. Windows and Web exports pass the existing verification pipeline.

Combat, enemies, health, damage, XP, level-up cards, Gold, and summoning remain outside Phase 1.
