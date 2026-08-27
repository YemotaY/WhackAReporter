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
godot --headless -s tests/smoke_test.gd
```

## Project Structure

```
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
