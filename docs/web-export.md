# Web and YouTube Playables export

The stock Godot 4.7.2 single-threaded release template produced a 37.68 MiB `index.wasm` for the Phase 0 project. That exceeds the current YouTube Playables hard limit of less than 30 MiB per individual file.

The project therefore uses a reproducible, size-optimized custom Web template. The build profile keeps 2D, UI, fallback Latin text shaping, audio, GDScript, JSON, and regex while disabling unused 3D/XR/networking/media import modules.

This profile is not permanent. When the project needs a disabled engine feature, enable it in `tools/build_profiles/web_playables.py`, rebuild, and rerun all Web tests.

The final Playables integration must also add the official YouTube SDK before game code, call the readiness APIs at the correct lifecycle points, and connect host audio/pause/save callbacks through `YouTubePlatformAdapter`.

## GitHub Pages preview

`.github/workflows/deploy-pages.yml` imports, tests, and exports the project after each push to `main`, then uploads `build/pages/` through the official GitHub Pages actions. The `Web Pages` preset intentionally uses the stock single-threaded export template available on the GitHub runner; the local `Web` preset continues to enforce the smaller custom template for YouTube Playables validation.

The repository owner must select **GitHub Actions** as the Pages publishing source once under **Settings → Pages**. The preview URL is `https://phanbatri2012.github.io/The_Last_King/` after the first successful deployment.
