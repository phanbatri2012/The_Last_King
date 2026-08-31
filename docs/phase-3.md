# Phase 3 slice — Endless Goblin ecology

This slice is complete when:

1. Goblins continue spawning for the lifetime of a run without a finite wave or kill limit;
2. simultaneous population starts at 9, grows by 1 every 45 seconds, and never exceeds 15;
3. enemies that fall far behind an unbounded travelling King are retired without rewards and replaced near the King;
4. the seeded spawn director selects enemy types from data-driven weights and preserves pending spawn state for Continue;
5. Raider, Brute, Archer, and Hexer Goblins have distinct health, defenses, speed, hatred range, damage, attack range, and attack speed;
6. the roster includes melee and ranged attack styles plus physical and magic damage;
7. an idle Goblin engages only when the King enters its own hatred range or damages it first;
8. once engaged, a Goblin pursues and attacks the King with its configured combat profile;
9. physical damage is reduced by armor and magic damage by magic resistance through `DamageResolver`;
10. defeated archetypes drop their own data-driven amount of visible run Gold;
11. the HUD reports current and target enemy density;
12. automated tests, Windows export, Web export, and browser QA pass.

XP, Run Level, level-up cards, and summoning remain separate Phase 3 slices.
