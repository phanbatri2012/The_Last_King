# The Last King

Top-down historical-fantasy survivor with army building, roguelite runs, and persistent meta progression.

Rise as a legendary ruler, survive enemy hordes, command ancient armies, collect gold, unlock skills, summon iconic warriors, and defeat colossal bosses.

## Phase 7 Active royal skills and run loop status

This repository contains the technical foundation and the first playable combat slice:

- Godot bootstrap and global service lifecycle;
- platform adapter boundary;
- versioned save/profile skeleton;
- English (US) canonical localization with Vietnamese support;
- open-ended faction roster data;
- data-driven Trần Hưng Đạo placeholder King;
- cyan-and-gold overhead King health bar with numeric HP and localized Run Level above the King, with duplicate health/level telemetry removed from the screen HUD;
- data-driven sword/blade versus bow/crossbow balance bands with King-specific attack ranges;
- procedurally tiled infinite battlefield with a smooth unbounded camera;
- normalized WASD/Arrow Keys and analog pointer/touch joystick movement;
- fourteen data-driven Goblin archetypes, including the complete Basic/Runner/Shield/Archer/Bomber/Shaman/Berserker/Champion/Wolf Rider/Warlock/Royal Guard/Demonized progression while retaining Brute and Hexer stable IDs;
- per-archetype health, armor, magic resistance, movement speed, hatred range, attack range, damage, and attack speed;
- melee/ranged and physical/magic enemy combat through the shared damage resolver;
- idle-until-alerted Goblins that engage only inside their hatred range or after the King attacks them;
- King damage on physical Goblin contact, resolved through the shared damage pipeline with a separate data-driven cooldown;
- a seeded 15-second Threat Budget Director with eleven timed phases, role unlocks, special/support budget limits, quadratic HP/damage escalation, capped speed, and platform-specific soft/hard caps;
- hatred ranges doubled for the four existing Goblin archetypes, with role-specific hatred ranges for every new archetype;
- quality/elite escalation when actor counts reach the platform soft cap, so Endless threat continues without requiring unbounded actor counts;
- nearest-target selection and automatic King attacks whose melee arcs and ranged projectiles pierce every target along their path;
- one shared damage resolver for King and enemy damage;
- bright run Gold drops collectable by the King or any living summoned soldier through one reward service, and a yellow HUD counter;
- centralized run Gold spending with no mixing into persistent account Gold;
- seven data-driven Đại Việt units: Spearman, Crossbowman, Royal Guard, Ambush Archer, Raider, Elephant Guard, and Royal War Elephant;
- distinct health, defense, speed, damage, reach, attack rate, summon cost, capacity cost, formation role, and placeholder silhouette for every unit;
- real pooled allied arrows and crossbow bolts with travel time and collision;
- a two-column touch/click roster plus PC/Web number-key hotkeys `1–7`, with no fixed living-soldier limit;
- five run-Gold upgrade levels for every Đại Việt unit type, applied immediately to existing soldiers and inherited by future summons;
- allied health, armor, formation following, automatic targeting, attacks, death events, and blue health bars;
- Goblin retaliation against allied attackers and Continue snapshots for the living army;
- real pooled Goblin arrows and magic Orbs with local charge indicators, no dashed aiming path, travel time, collision, and dodge windows;
- rare seeded green Healing Orb drops that restore a data-driven percentage of King maximum HP, then heal wounded soldiers when the King is full;
- mouse-hold and touch-hold movement across the battlefield alongside WASD and the virtual joystick;
- Continue snapshots for uncollected Healing Orbs and deterministic healing-drop RNG;
- XP rewards for every Goblin archetype, a slower 60-XP opening threshold that grows by 30 each level, and three seeded skill choices whenever the King levels up;
- six three-rank King skills covering damage, attack/movement speed, reach, health/defense, unlimited-piercing royal waves, and periodic area damage, now with distinct upgrade/cast effects;
- a battle-pausing bilingual level-up overlay that shows each skill's current/next rank and localized description, plus Continue snapshots for XP, Run Level, skill ranks, skill-choice RNG, and army upgrades;
- an uncluttered summon HUD with unit-upgrade details moved into an on-demand, battle-pausing overlay opened by click/touch or the `U` key;
- a data-driven Rage resource gained from combat, damage taken, kills, and steady battlefield momentum, with full Continue state;
- three localized Trần Hưng Đạo active skills on touch buttons and `Q/E/R`: a forward piercing sword cone, a timed defensive/healing command, and a pooled piercing royal-wave ultimate;
- live Rage, readiness, cost, and cooldown feedback plus distinct auto-aimed cast effects and persistent guard feedback;
- a seeded Boss Director with the full twelve-Boss ladder from Goblin Brute at 1:30 through Goblin God-King at 30:00, pre-Boss pressure reduction, post-kill relief, rewards, and Ascendant cycles after minute 30;
- one readable signature skill per Boss, enhanced below 50% HP, with movement counterplay, recovery windows, centralized damage, add spawning, Stagger vulnerability, and Continue state;
- localized combat HUD, defeat/retry flow, a scored run summary, desktop Exit Game button, and in-memory Continue state;
- desktop and web export presets;
- headless smoke tests.

Persistent account progression, destructible Boss objectives, and polished historical art remain later slices.

## Toolchain

- Godot 4.7.2 Standard
- GDScript
- Compatibility renderer
- Git

The repository can use a portable editor at `.tools/godot/Godot_v4.7.2-stable_win64.exe`; automation uses the matching console executable. The `.tools` directory is ignored by Git.

See `docs/toolchain-setup.md` for the one-time portable editor, export-template, and size-optimized Web-template setup.

## Run

Open `project.godot` in Godot and run the project, or from PowerShell:

```powershell
.\.tools\godot\Godot_v4.7.2-stable_win64.exe --path . --editor
```

## Test

```powershell
.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd
```

## Export

```powershell
.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" build/windows/the-last-king.exe
.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Web" build/web/index.html
```

Generated exports belong in `build/` and are not committed.

Pushes to `main` deploy the latest Web preview to [GitHub Pages](https://phanbatri2012.github.io/The_Last_King/) and also produce a downloadable `the-last-king-web` artifact in GitHub Actions.

To import, test, smoke-run, export both targets, and validate the Web bundle in one command:

```powershell
.\tools\run_phase2.ps1
```
