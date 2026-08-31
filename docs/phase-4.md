# Phase 4A slice — Đại Việt Spearman summoning

This slice is complete when:

1. the King owns a data-driven maximum Army Capacity of 20;
2. a visible, touch-accessible summon button and the Q key summon one Đại Việt Spearman when affordable;
3. a Spearman costs 15 temporary run Gold and consumes 2 Army Capacity;
4. spending is rejected without sufficient Gold or Capacity and all run Gold mutations remain centralized;
5. Spearman health, defenses, movement, attack, summon, formation, and presentation values come from the unit catalog;
6. summoned units occupy deterministic ring slots relative to the moving King;
7. Spearmen detect and automatically attack nearby Goblins without scanning the full world each frame;
8. allied attacks pass through `DamageResolver` and alert Goblins outside their normal hatred range;
9. alerted Goblins can retaliate against and kill allied units;
10. King, allied, and enemy overhead health bars use distinct colors;
11. `unit_summoned` and `unit_died` events are emitted through the existing event boundary;
12. Continue preserves unit ID, instance ID, health, position, Gold, and used Army Capacity;
13. automated tests, Windows export, Web export, and browser QA pass.

Crossbowmen, a multi-choice summon panel, Brace/Exposed, XP, Run Level, and level-up cards remain later slices.

## Phase 4B slice — survival, recovery, and dodgeable ranged attacks

This slice is complete when:

1. Goblin Archer arrows and Goblin Hexer magic Orbs are real lightweight projectiles rather than post-hit decoration;
2. ranged enemies telegraph and lock their firing direction before projectile release;
3. the King can sidestep a shot with ordinary movement and takes damage only on collision;
4. allied units can intercept enemy projectiles because the first player-team body is hit;
5. high-frequency enemy projectiles come from a prewarmed battle-owned pool;
6. each Goblin archetype has a seeded, data-driven Healing Orb chance and recovery fraction;
7. green Healing Orbs remain when the King is at full HP and heal through one resolver when collected while damaged;
8. green visual recovery feedback distinguishes healing from damage;
9. uncollected Healing Orbs and drop RNG state survive Continue;
10. holding the left mouse button or one unconsumed touch moves the King in that screen direction without breaking WASD, joystick, or combat UI;
11. automated tests, Windows export, Web export, and browser QA pass.
