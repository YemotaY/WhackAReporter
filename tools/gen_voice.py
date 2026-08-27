#!/usr/bin/env python3
"""Generate retro 'voice babble' clips (Animal-Crossing style) for
Whack-A-Reporter. Two distinct voices:
- reporter: high, fast, ends with rising 'question' intonation
- president: low, slow, grumbly, falling intonation
Drop real voice-actor WAVs with the same filenames into assets/voice/
to replace these placeholders.
"""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "voice")
os.makedirs(OUT, exist_ok=True)

def write(name, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))
    print("wrote", path)

def syllable(f0, dur, vowel_f):
    """One babble syllable: harmonic-rich tone with vibrato + formant boost."""
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        vib = 1.0 + 0.02 * math.sin(2 * math.pi * 5.5 * t)
        f = f0 * vib
        s = 0.0
        for h in range(1, 9):
            amp = 1.0 / h
            # crude formant: boost harmonics near vowel_f
            hf = f * h
            amp *= 1.0 + 2.2 * math.exp(-((hf - vowel_f) ** 2) / (2 * 300.0 ** 2))
            s += amp * math.sin(2 * math.pi * hf * t)
        s *= 0.10
        # amplitude envelope per syllable
        env = min(1.0, t / 0.015) * min(1.0, (dur - t) / (dur * 0.35))
        out.append(s * env)
    return out

def babble(seed, base_f0, n_syll, syll_dur, contour):
    """contour(k) -> pitch multiplier for syllable k in [0,1)."""
    rng = random.Random(seed)
    vowels = [350, 600, 800, 1000, 1200]
    out = []
    for k in range(n_syll):
        u = k / max(1, n_syll - 1)
        f0 = base_f0 * contour(u) * rng.uniform(0.92, 1.08)
        d = syll_dur * rng.uniform(0.7, 1.3)
        out += syllable(f0, d, rng.choice(vowels))
        # tiny gap
        out += [0.0] * int(SR * rng.uniform(0.01, 0.04))
    return out

def reporter(seed, n_syll=9):
    # fast, high, question intonation (pitch rises steeply at the end)
    return babble(seed, 250, n_syll, 0.075, lambda u: 1.0 + 0.08 * math.sin(u * 6) + (0.55 * (u - 0.7) if u > 0.7 else 0))

def president(seed, n_syll=7):
    # slow, low, self-satisfied falling contour
    return babble(seed, 105, n_syll, 0.12, lambda u: 1.12 - 0.25 * u + 0.05 * math.sin(u * 4))

clips = {
    "reporter_q1.wav": reporter(11, 8),
    "reporter_q2.wav": reporter(23, 10),
    "reporter_q3.wav": reporter(37, 9),
    "reporter_q4.wav": reporter(51, 11),
    "prez_whack1.wav": president(7, 4),
    "prez_whack2.wav": president(13, 5),
    "prez_whack3.wav": president(29, 3),
    "prez_start.wav": president(3, 8),
    "prez_over.wav": president(97, 9),
    "prez_taunt1.wav": president(41, 6),
    "prez_level2.wav": president(59, 7),
}
for name, samples in clips.items():
    write(name, samples)
