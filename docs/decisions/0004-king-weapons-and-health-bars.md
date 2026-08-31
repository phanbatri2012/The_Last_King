# 0004 — King weapons and overhead health identity

## Decision

King health is always visible above the character. Its cyan fill and gold border are reserved for Kings and must remain visually distinct from the red enemy health treatment and future unit treatments.

King weapon balance is data-driven through `data/combat/weapon_archetypes.json`:

- sword and blade archetypes use melee attack style and occupy the higher damage bands;
- bow and crossbow archetypes use ranged attack style and occupy lower damage bands with longer range bands;
- the lowest melee damage must remain above the highest ranged damage;
- the lowest ranged reach must remain above the highest melee reach;
- each King still defines an individual `attack.range` inside the selected archetype's range bounds.

The content database validates these invariants at startup. Gameplay consumes the resolved archetype and does not branch on a King ID or faction ID.
