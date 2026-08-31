# Phase 0 toolchain setup

All third-party binaries and source checkouts live under `.tools/` and are ignored by Git.

## Godot editor and official export templates

1. Download Godot 4.7.2 Standard for Windows and its export templates from the official Godot archive.
2. Extract the editor and console executables into `.tools/godot/`.
3. Install the official 4.7.2 export templates through the editor. When using self-contained mode, they belong under `.tools/godot/editor_data/export_templates/4.7.2.stable/`.

The automation expects `.tools/godot/Godot_v4.7.2-stable_win64_console.exe` by default.

## Size-optimized Web template

The stock Web template is too large for the project's YouTube Playables per-file target. Build the project profile once:

```powershell
git clone --depth 1 --branch 4.7.2-stable https://github.com/godotengine/godot.git .tools/godot-src-4.7.2
git clone https://github.com/emscripten-core/emsdk.git .tools/emsdk
.\.tools\emsdk\emsdk.bat install 4.0.20
.\.tools\emsdk\emsdk.bat activate 4.0.20
py -3.11 -m venv .tools/build-venv
.\.tools\build-venv\Scripts\python.exe -m pip install scons==4.11.1
.\tools\build_web_template.ps1
```

This creates the ignored `tools/export_templates/web_playables_release.zip` referenced by the Web export preset. Rebuild it after changing Godot patch versions or enabling an engine feature disabled by `tools/build_profiles/web_playables.py`.

## Verify everything

```powershell
.\tools\run_phase0.ps1
```

The command imports the project, runs automated tests, smoke-runs the Bootstrap scene, exports Windows and Web release builds, and validates the Web bundle limits.
