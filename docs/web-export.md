# Web and YouTube Playables export

The stock Godot 4.7.2 single-threaded release template produced a 37.68 MiB `index.wasm` for the Phase 0 project. That exceeds the current YouTube Playables hard limit of less than 30 MiB per individual file.

The project therefore uses a reproducible, size-optimized custom Web template. The build profile keeps 2D, UI, fallback Latin text shaping, audio, GDScript, JSON, and regex while disabling unused 3D/XR/networking/media import modules.

This profile is not permanent. When the project needs a disabled engine feature, enable it in `tools/build_profiles/web_playables.py`, rebuild, and rerun all Web tests.

The final Playables integration must also add the official YouTube SDK before game code, call the readiness APIs at the correct lifecycle points, and connect host audio/pause/save callbacks through `YouTubePlatformAdapter`.

## GitHub Actions Web preview

`.github/workflows/build-web.yml` imports, tests, and exports the project after each push to `main`, then uploads `build/pages/` as the downloadable `the-last-king-web` workflow artifact. The `Web Preview` preset intentionally uses the stock single-threaded export template available on the GitHub runner; the local `Web` preset continues to enforce the smaller custom template for YouTube Playables validation.

The current GitHub plan does not support Pages while this repository is private. A public URL can be enabled later after the owner either makes the repository public or upgrades to a plan that supports private-repository Pages.
