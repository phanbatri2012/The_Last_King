# Decision 0008 — Run progression and unlimited army growth

## Status

Accepted.

## Decision

King progression is temporary battle state. Enemy XP enters through `RewardGrantService`; when a threshold is met, an ordinary `KingProgressionController` consumes the threshold, advances Run Level, generates three choices from seeded gameplay RNG, and requests the `level_up` pause reason. An ordinary `KingSkillRuntime` applies data-driven passive modifiers and schedules automatic skills. Neither controller is an autoload.

King attacks are piercing by default. Melee attacks resolve every living enemy in the forward arc, and ranged/royal-wave projectiles keep moving until lifetime expiry while remembering instance IDs already hit. Soldier projectiles retain their existing single-hit behavior unless their request explicitly opts into piercing.

Army count is not capped by the King's legacy capacity value. Summons remain economically bounded by temporary run Gold and technically bounded by runtime performance. Unit upgrades are purchased per stable unit ID, immediately recompute all matching living units, and are also applied when that type is summoned later. Upgrade levels live in `BattleSession.upgrades.army`; individual snapshots repeat the level so old or partially restored snapshots degrade safely.

The active Goblin target starts at 14 and grows to 24. This increases battlefield pressure while preserving a strict simultaneous-enemy cap, staggered spawning, distant-enemy recycling, pooled projectiles, and no per-frame full-world scan for ordinary attacks.
