# Phase 5 slice — King progression and unlimited army growth

This slice is complete when:

1. every Goblin grants temporary run XP through `RewardGrantService`;
2. XP thresholds grow by level and Continue preserves Run Level, unspent XP, and seeded choice RNG;
3. reaching a level threshold pauses battle simulation and presents three localized, seeded skill choices;
4. selecting a card resumes the battle and applies one of six three-rank King skills;
5. passive skills modify damage, cooldown, movement, range, slash arc, health, armor, or magic resistance without changing the base content record;
6. automatic skills release pooled royal waves or damage all enemies in a periodic area;
7. King melee arcs, King arrows/bolts, and royal-wave projectiles continue through all valid enemies in their path, while each target is damaged at most once per projectile;
8. summon count has no fixed gameplay ceiling, but every summon still spends temporary run Gold;
9. each Đại Việt unit type has five run-Gold upgrade levels that strengthen health, damage, defense, and attack speed;
10. a unit-type upgrade affects living soldiers immediately, is inherited by later summons, and survives Continue independently of the living army snapshot;
11. the endless battlefield begins at 14 Goblins, grows gradually, and remains capped at 24 active enemies for Web/low-end mobile performance;
12. English and Vietnamese UI, automated tests, Windows export, Web export, and browser QA pass.

The referenced design document was not publicly readable during implementation (HTTP 401). This slice therefore uses the repository's already-reserved `run_level`, `run_xp`, `skills`, `upgrades`, and seeded RNG fields as the authoritative implementation boundary. The data-driven curve and skill catalog can be rebalanced later without replacing the runtime systems.
