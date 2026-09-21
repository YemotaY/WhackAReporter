# Whack-A-Reporter

A retro-arcade 2D top-down mini game for **Godot 4.7**. You are *da Präsident* —
reporters keep popping out of podiums to ask serious questions. Bonk them with
your gavel before their question ring fills up, or your approval drops!

![Godot 4.7](https://img.shields.io/badge/Godot-4.7-blue) ![License: MIT](https://img.shields.io/badge/License-MIT-green)

## How to Play

| Action | Input |
| --- | --- |
| Swing gavel | Left mouse click |

- **Q&A satire flow**: each reporter *speaks* their question when popping up
  (neural TTS). Your hit window matches the spoken question length at early
  levels — bonk them and the audio cuts off and da Präsident delivers his
  ironic answer. Later levels shrink the window below the question length.
- **Hit a reporter** before the `?` ring fills: `+100 × combo`.
- **Miss a swing** and your combo resets.
- **Let a question finish** and you lose one ❤ Approval. Run out = **IMPEACHED!**
- **10 levels, 2 minutes each** — survive the full **20-minute term** to get **RE-ELECTED** (+5000 bonus).
  - Level 2+: podiums slide sideways (faster every level)
  - Level 6+: podiums also bob vertically
  - Each new level restores one ❤ Approval (max 5)
- **Local leaderboard**: top-10 arcade high scores with 3-letter initials, saved to `user://leaderboard.json`.

## Run

```bash
godot --path .        # play
godot -e --path .     # open in editor
```

## Tests

Headless gameplay smoke test (spawning, hit detection, lives, game over, restart):

```bash
godot --headless -s tests/smoke_test.gd     # or: make test-source
make test                                   # + the same test inside an obfuscated, encrypted export
```

## Release Pipeline

Builds are **encrypted, obfuscated and stripped**; everything lives in
`tools/release/` and is driven by the `Makefile`.

```bash
make setup            # venv + SCons, Godot source -> build/godot, key, git hooks
make setup-all        # + llvm-mingw (Windows), emsdk (Web), JDK + Android SDK/NDK
make templates        # compile hardened export templates (once per key / engine version)

make linux            # export/v<VERSION>/linux/
make windows          # export/v<VERSION>/windows/
make web              # export/v<VERSION>/web/ + itch.io zip
make android          # export/v<VERSION>/android/*.apk (signed)
make ios              # export/v<VERSION>/ios/*.xcodeproj  (template must be built on macOS)
make itch             # web export + `butler push` to itch.io
make release          # test + linux + windows + web + android + verify
VERSION=1.1.0 make release
```

### Anti-reverse-engineering layers

| Layer | What it does |
| --- | --- |
| [GDMaim](https://github.com/cherriesandmochi/gdmaim) (`addons/gdmaim`) | Renames every identifier, strips comments/annotations, shuffles declarations, emits compressed binary tokens instead of source. Settings: `.gdmaim/export.cfg`. |
| PCK encryption | `encrypt_pck` + `encrypt_directory` on every preset: AES-256 over file contents **and** the file table (no readable paths). |
| Custom export templates | Compiled from source (`build/godot`) with the key baked in, `production=yes`, symbols stripped, `disable_overrides=yes` (no `override.cfg`) and Godot 4.7's `disable_path_overrides` (no `--main-pack`, `-s`, `--path`). Official templates cannot open the PCKs. |
| Silent runtime | `disable_stdout` / `disable_stderr` are on, so no script names or errors leak to logs. |
| Shipping filter | `tests/`, `tools/`, `docs/` and the obfuscator itself are excluded from every PCK. |

No scheme makes a client binary impossible to reverse; the key can always be
recovered by someone debugging the running process. These layers make the
result expensive: even a recovered PCK yields only renamed, comment-free
bytecode.

### Secrets (never committed)

```
secrets/encryption.key              256-bit PCK key  (make setup generates it)
secrets/android_release.keystore    + .pass          (make setup-android)
secrets/itch_api_key                for make itch
secrets/gdmaim_source_maps/         obfuscation maps - needed to read crash reports
.env                                VERSION, ITCH_TARGET (copy of .env.example)
.godot/export_credentials.cfg       written by Godot; synced from secrets/ via make sync-creds
```

`secrets/`, `build/`, `export/`, `.env` and `.godot/` are git-ignored, and
`tools/release/check_secrets.sh` runs as a pre-commit hook (installed by
`make setup`) that refuses commits containing the key, keystore passwords or
forbidden paths. `make check-secrets` scans the whole tree.

**Back up `secrets/` somewhere safe** - losing the key means rebuilding the
templates, and losing the keystore means no more Play Store updates.

### Verification

`make test` / `make verify` prove for each artefact that no source identifier
or `res://` path survives in plaintext, the PCK directory is flagged encrypted,
the release binary boots headless and ignores CLI path overrides, and (via the
`Linux Test` preset) that the full gameplay smoke test passes *inside* the
obfuscated, encrypted build.

## Project Structure

```
addons/gdmaim/           GDScript obfuscator (export plugin, MIT)
assets/
  crt_overlay.gdshader   CRT scanline/vignette overlay
  sfx/                   synthesized sound effects (WAV)
  voice/                 dialogue.json + TTS-generated voice clips (WAV)
scenes/main.tscn         main scene (game + UI)
scripts/
  main.gd                game loop, levels, score, spawning, leaderboard, HUD
  hole.gd                podium: pop-up/sink animation, question timer, hit box
  reporter.gd            procedurally drawn reporter (random suits/hair)
  hammer.gd              gavel mouse cursor with swing animation
  voice.gd               Q&A dialogue playback with subtitles (VoiceBox)
tests/smoke_test.gd      headless gameplay test
tools/
  gen_sfx.py             regenerates assets/sfx/*.wav
  tts_pipeline.py        dialogue.json -> WAVs via Piper (espeak-ng fallback)
  release/               build/export/verify/publish scripts (see Release Pipeline)
export_presets.cfg       Godot export presets (hardened; no secrets inside)
Makefile                 release entry points
build/                   (git-ignored) Godot source, toolchains, compiled templates
secrets/                 (git-ignored) encryption key, keystores, API keys
```

## Voice Pipeline (TTS)

All spoken lines live in `assets/voice/dialogue.json`: single president lines
plus `qa` pairs (reporter question → president answer) that drive gameplay.
Subtitles are read from the same file.

The pipeline uses **Piper** neural TTS (natural voices; deep pompous male for
the president, urgent male/female reporters) and falls back to espeak-ng.

One-time setup:

```bash
sudo pacman -S python-pip            # or your distro's pip package
python3 -m venv ~/.local/share/piper-venv
~/.local/share/piper-venv/bin/pip install piper-tts
mkdir -p ~/.local/share/piper-voices && cd ~/.local/share/piper-voices
for v in hfc_male/medium/en_US-hfc_male-medium joe/medium/en_US-joe-medium \
         hfc_female/medium/en_US-hfc_female-medium; do
  curl -LO "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/$v.onnx"
  curl -LO "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/$v.onnx.json"
done
```

Regenerate all WAVs after editing the dialogue:

```bash
python3 tools/tts_pipeline.py
```

To use real voice-actor recordings, replace the WAVs in `assets/voice/` —
keep the filenames (`<line_key>.wav`, `qa_<id>_q.wav`, `qa_<id>_a.wav`).

## License

[MIT](LICENSE). All code and generated assets are original to this project.
This is a work of satire; any resemblance to actual presidents is comedic.

## SUPPORT

| | |
|---|---|
| 🎮 **Play** | [yemotay.itch.io/whack-a-reporter](https://yemotay.itch.io/whack-a-reporter) |
| ⭐ **Source** | [github.com/YemotaY/WhackAReporter](https://github.com/YemotaY/WhackAReporter) |
| ❤ **Donate** | [paypal.me/YemotaY](https://www.paypal.me/resellwithpi) |
