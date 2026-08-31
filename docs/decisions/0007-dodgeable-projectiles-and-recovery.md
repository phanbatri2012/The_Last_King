# Decision 0007 — Dodgeable projectiles and bounded recovery

## Status

Accepted.

## Decision

Ranged Goblins no longer resolve damage when their attack cooldown fires. They telegraph a locked direction and submit a projectile request to a prewarmed `EnemyProjectilePool` owned by the current battle. The projectile is an ordinary lightweight `Area2D`; only collision with the King or a summoned ally passes damage through `DamageResolver`. This makes normal movement a complete dodge mechanic without adding another combat button.

Recovery comes from rare green Healing Orbs instead of passive out-of-combat regeneration. Each enemy defines a seeded drop chance and maximum-health recovery fraction. A full-health King does not consume the Orb, and accepted recovery passes through `HealingResolver`. The drop director's RNG state and all uncollected Orbs are included in the current battle snapshot.

Mouse and touch hold movement is screen-relative while held, so movement continues as the camera follows the King. GUI controls consume their own presses before battle input starts a hold. Input priority is virtual joystick, hold movement, then keyboard.
