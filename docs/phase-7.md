# Phase 7 — Active royal skills and complete run feedback

Phase 7 adds a data-driven active-skill layer without replacing the existing seeded level-up skills.

## Playable slice

- Rage is bounded at 100 and is earned through time in combat, King damage dealt, King damage received, enemy kills, and Boss kills.
- Trần Hưng Đạo uses `Q`, `E`, and `R` on desktop/web or the three touch buttons:
  - Vạn Kiếp Trảm: a wide forward cone that damages every enemy in its path.
  - Hịch Tướng Sĩ: immediate recovery plus temporary physical and magic defense.
  - Bạch Đằng Phá Trận: nine pooled, piercing royal waves in an auto-aimed fan.
- Rage, cooldowns, and the remaining guard duration survive Continue snapshots.
- The defeat screen reports survival time, score, Goblins and Bosses defeated, King level, remaining run Gold, peak army size, and active skill casts.

## Architecture

- Active skill content lives in the versioned King skill catalog and is validated at startup.
- `KingActiveSkillController` is an ordinary battle node rather than a global service.
- Active damage and healing use the shared resolvers; projectiles use the existing ally pool.
- Damage resolution publishes one event through `GameEventBus` so Rage generation does not bypass combat rules.
- Phase 7 runtime state and summary counters live in `BattleSession` schema version 3.

## Acceptance baseline

- `Q/E/R` and touch buttons invoke the same runtime methods.
- Skills cannot cast without enough Rage or during cooldown.
- Defense bonuses expire using simulation delta, not wall-clock time.
- Existing summons remain on number keys `1–7`.
- Windows and Web exports retain all Phase 6 behavior and pass the automated suite.
