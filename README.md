# The Last King

Top-down historical-fantasy survivor with army building, roguelite runs, and persistent meta progression.

Rise as a legendary ruler, survive enemy hordes, command ancient armies, collect gold, unlock skills, summon iconic warriors, and defeat colossal bosses.

## Phase 4 army summoning status

This repository contains the technical foundation and the first playable combat slice:

- Godot bootstrap and global service lifecycle;
- platform adapter boundary;
- versioned save/profile skeleton;
- English (US) canonical localization with Vietnamese support;
- open-ended faction roster data;
- data-driven Trần Hưng Đạo placeholder King;
- cyan-and-gold overhead King health bar, visually distinct from red enemy health bars;
- data-driven sword/blade versus bow/crossbow balance bands with King-specific attack ranges;
- procedurally tiled infinite battlefield with a smooth unbounded camera;
- normalized WASD/Arrow Keys and analog pointer/touch joystick movement;
- four data-driven Goblin archetypes: Raider, Brute, Archer, and Hexer;
- per-archetype health, armor, magic resistance, movement speed, hatred range, attack range, damage, and attack speed;
- melee/ranged and physical/magic enemy combat through the shared damage resolver;
- idle-until-alerted Goblins that engage only inside their hatred range or after the King attacks them;
- unlimited lifetime spawning with a moderate active density that grows gradually from 9 to a hard cap of 15;
- nearest-target selection and automatic King attacks;
- one shared damage resolver for King and enemy damage;
- bright run Gold drops, collection through one reward service, and a yellow HUD counter;
- centralized run Gold spending with no mixing into persistent account Gold;
- data-driven Đại Việt Spearman summoning for 15 run Gold and 2 Army Capacity;
- a visible touch/keyboard summon control and a 20-point King Army Capacity;
- allied health, armor, formation following, automatic targeting, attacks, death events, and blue health bars;
- Goblin retaliation against allied attackers and Continue snapshots for the living army;
- localized combat HUD, defeat/retry flow, desktop Exit Game button, and in-memory Continue state;
- desktop and web export presets;
- headless smoke tests.

XP, Run Level, level-up cards, Crossbowmen, and advanced formations remain later slices.

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
