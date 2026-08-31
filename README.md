# The Last King

Top-down historical-fantasy survivor with army building, roguelite runs, and persistent meta progression.

## Phase 1 status

This repository contains the technical foundation and the first playable movement slice:

- Godot bootstrap and global service lifecycle;
- platform adapter boundary;
- versioned save/profile skeleton;
- English (US) canonical localization with Vietnamese support;
- open-ended faction roster data;
- data-driven Trần Hưng Đạo placeholder King;
- responsive empty arena with bounded smooth camera;
- normalized WASD/Arrow Keys and analog pointer/touch joystick movement;
- in-memory movement session with Continue support;
- desktop and web export presets;
- headless smoke tests.

Combat and the survivor loop intentionally begin in later phases.

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

To import, test, smoke-run, export both targets, and validate the Web bundle in one command:

```powershell
.\tools\run_phase1.ps1
```
