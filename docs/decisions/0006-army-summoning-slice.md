# Decision 0006 — Battle-owned army summoning

## Status

Accepted.

## Decision

`ArmyController` is an ordinary battle node, not a global autoload. It owns the summoned unit instances, capacity accounting, deterministic formation slots, and battle snapshots. Individual units remain ordinary `CharacterBody2D` nodes composed with the shared health, defense, targeting, and damage systems.

The unit catalog defines faction ownership, combat stats, temporary run Gold cost, integer Army Capacity cost, formation policy, and placeholder presentation. Engine code does not branch on the Đại Việt faction ID or a specific Spearman behavior.

Run Gold spending is added to the existing centralized run currency boundary. Summoning first validates battle state, capacity, and affordability, then spends run Gold and creates the unit. Failed creation refunds through the same grant boundary. Persistent account Gold remains untouched.

Phase 4A exposes one direct summon choice because only the Spearman is implemented. The button stays visible but disabled until affordable, so the player can discover the army loop without opening a large combat menu. A multi-choice panel will replace it when Crossbowmen and Royal Guards enter the roster.

Allied units use collision layer 4 and query only enemy layer 2 through local detection areas. This avoids per-frame full-world scans and keeps the design suitable for Web and low-end mobile.
