# Phase 8 — Royal Treasury and persistent progression

Phase 8 closes the first persistent roguelite loop: battle, defeat, collect a permanent reward, strengthen the King at court, and begin a stronger new run.

## Playable slice

- Defeat settles the run once and awards Account Gold from survival time, Goblin kills, Boss kills, and King run level.
- The defeat summary shows the exact Account Gold reward and new account total.
- The Royal Treasury is available from the main court in English and Vietnamese.
- Four permanent upgrades each have five explicit data-driven ranks:
  - Royal Vitality increases maximum health.
  - Royal Training increases attack damage.
  - Marching Discipline increases movement speed, armor, and magic resistance.
  - War Chest adds starting Run Gold to every new run.
- Career statistics track completed runs, total Goblin/Boss kills, play time, best score, and longest survival.

## Architecture

- Account progression content and its reward curve live in `data/progression/account_progression.json` and are validated at startup.
- `RewardGrantService` remains the only route for persistent rewards and Account Gold spending.
- `AccountProgressionService` resolves purchases and composes permanent King modifiers without faction checks in gameplay code.
- `run_gold` remains inside `BattleSession`; `account_gold` remains inside the persistent player profile.
- Player profiles migrate from schema 1 to schema 2. Battle snapshots migrate from schema 3 to schema 4.
- Permanent upgrades affect only newly created runs, so Continue restores the same battle state without applying bonuses twice.

## Acceptance baseline

- A run can be settled only once even if the defeat callback or summary refresh runs repeatedly.
- Purchases reject unknown upgrades, maximum ranks, and insufficient Account Gold.
- Every cost, rank, effect, name, and description is data-driven and bilingual.
- Old profiles retain resources and statistics after migration.
- Windows and Web exports retain all Phase 7 controls and combat behavior.
