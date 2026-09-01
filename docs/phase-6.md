# Phase 6 slice — Goblin threat and Boss progression

This slice is complete when:

1. the King shows localized Run Level above an overhead cyan/gold health bar containing numeric current/max HP;
2. duplicate King HP, level, and XP bar are absent from the screen HUD, while level-up choices show skill rank and localized descriptions;
3. the four existing Goblin archetypes have exactly double their previous hatred distance and still retaliate when attacked outside that distance;
4. the Goblin catalog contains the complete progression roster plus retained stable variants, with individual health, damage, defense, speed, reach, attack cadence, role, spawn cost, unlock time, and ability data;
5. the Threat Director calculates a seeded 15-second budget, unlocks the roster by phase, keeps special/support pressure bounded, and applies the specified quadratic HP/damage and capped speed formulas;
6. target quantity grows from the readable opening phase through Endless and obeys platform soft/hard caps;
7. reaching a soft cap converts later pressure into stronger elite/ascendant spawns instead of requiring unbounded actors;
8. all twelve Bosses spawn in order from 1:30 through 30:00 and later continue through seeded Ascendant cycles;
9. each Boss exposes one recognizable signature skill with a clear telegraph, movement counterplay, recovery window, enhanced form, reward, and Stagger state;
10. save/continue preserves regular-enemy scaling, Director RNG/budget, active Boss HP/signature/Stagger, Boss schedule, adds, drops, and elapsed battle time;
11. every King skill selection creates a distinct visual flourish, while Piercing Wave and Dragon Aura casts have materially clearer battlefield effects;
12. persistent unit-upgrade details are absent from the corner summon HUD and remain accessible through a separate click/touch and `U`-key overlay;
13. English and Vietnamese localization, automated tests, Windows export, Web export, and visual QA pass.

The implementation follows `The_Last_King_Goblin_Boss_Progression.docx` v1.0. The canonical Boss and Threat values live in `data/enemies/goblin_threat_progression.json`; runtime code consumes those records without hard-coding the ladder in arena logic.
