# Whack-A-Reporter

A retro-arcade 2D top-down mini game for **Godot 4.7**. You are *da Präsident* —
reporters keep popping out of podiums to ask serious questions. Bonk them with
your gavel before their question ring fills up, or your approval drops!

![Godot 4.7](https://img.shields.io/badge/Godot-4.7-blue) ![License: MIT](https://img.shields.io/badge/License-MIT-green)

## How to Play

| Action | Input |
| --- | --- |
| Swing gavel | Left mouse click |

- **Hit a reporter** before the `?` ring around their speech bubble fills: `+100 × combo`.
- **Miss a swing** and your combo resets.
- **Let a question finish** and you lose one ❤ Approval. Three questions = **IMPEACHED!**
- Reach **1500 points** to enter **Level 2**, where the podiums start moving.
- Difficulty ramps continuously: reporters spawn faster and ask faster.

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
  voice/                 voice clips + retro babble placeholders (WAV)
scenes/main.tscn         main scene (game + UI)
scripts/
  main.gd                game loop, levels, score, spawning, HUD
  hole.gd                podium: pop-up/sink animation, question timer, hit box
  reporter.gd            procedurally drawn reporter (random suits/hair)
  hammer.gd              gavel mouse cursor with swing animation
  voice.gd               voice clip + subtitle playback (VoiceBox)
tests/smoke_test.gd      headless gameplay test
tools/
  gen_sfx.py             regenerates assets/sfx/*.wav
  gen_voice.py           regenerates assets/voice/*.wav
```

## Replacing the Voice Clips

The shipped voice clips are synthesized retro "babble" placeholders
(Animal-Crossing style). To use real voice-actor recordings, simply replace
the WAV files in `assets/voice/` — keep the same filenames. The spoken text
for each clip (shown as subtitles) is defined in `scripts/voice.gd` (`LINES`).

| File | Line |
| --- | --- |
| `reporter_q1..4.wav` | Reporter questions |
| `prez_whack1..3.wav` | "FAKE NEWS!", "NEXT QUESTION!", "WRONG!" |
| `prez_start.wav` | Briefing intro |
| `prez_over.wav` | Impeachment lament |
| `prez_taunt1.wav` | Combo taunt |
| `prez_level2.wav` | Level 2 reaction |

Regenerate all placeholder audio with:

```bash
python3 tools/gen_sfx.py && python3 tools/gen_voice.py
```

## License

[MIT](LICENSE). All code and generated assets are original to this project.
This is a work of satire; any resemblance to actual presidents is comedic.
