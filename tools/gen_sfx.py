#!/usr/bin/env python3
"""Generate WAV sound effects for Whack-A-Reporter."""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
os.makedirs(OUT, exist_ok=True)

def write(name, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))
    print("wrote", path)

def env(i, n, a=0.005, r=0.3):
    t = i / SR
    dur = n / SR
    att = min(1.0, t / a) if a > 0 else 1.0
    rel = min(1.0, (dur - t) / (dur * r))
    return att * max(0.0, rel)

def whack():  # punchy thump + noise crack
    n = int(SR * 0.25)
    out = []
    for i in range(n):
        t = i / SR
        f = 180 * math.exp(-t * 14) + 50
        s = math.sin(2 * math.pi * f * t) * 0.9
        s += (random.random() * 2 - 1) * 0.5 * math.exp(-t * 40)
        out.append(s * env(i, n))
    return out

def pop():  # reporter pops up
    n = int(SR * 0.18)
    out = []
    for i in range(n):
        t = i / SR
        f = 300 + 900 * (t / 0.18)
        out.append(math.sin(2 * math.pi * f * t) * 0.6 * env(i, n, 0.002, 0.5))
    return out

def question():  # annoying rising "question" chirp
    n = int(SR * 0.5)
    out = []
    for i in range(n):
        t = i / SR
        f = 500 + 500 * math.sin(2 * math.pi * 6 * t) + 400 * t
        s = 0.4 * (1 if math.sin(2 * math.pi * f * t) > 0 else -1)  # square-ish
        out.append(s * env(i, n, 0.01, 0.25))
    return out

def miss():  # descending womp
    n = int(SR * 0.3)
    out = []
    for i in range(n):
        t = i / SR
        f = 400 * math.exp(-t * 6) + 80
        out.append(math.sin(2 * math.pi * f * t) * 0.55 * env(i, n))
    return out

def fail():  # game over descending triad
    seq = [392, 330, 262, 196]
    out = []
    for f in seq:
        n = int(SR * 0.22)
        for i in range(n):
            t = i / SR
            s = 0.5 * math.sin(2 * math.pi * f * t) + 0.2 * math.sin(2 * math.pi * f * 2 * t)
            out.append(s * env(i, n, 0.01, 0.4))
    return out

def start():  # ascending fanfare
    seq = [262, 330, 392, 523]
    out = []
    for f in seq:
        n = int(SR * 0.12)
        for i in range(n):
            t = i / SR
            s = 0.5 * math.sin(2 * math.pi * f * t) + 0.25 * math.sin(2 * math.pi * f * 2 * t)
            out.append(s * env(i, n, 0.005, 0.3))
    return out

def tick():  # UI blip
    n = int(SR * 0.06)
    return [math.sin(2 * math.pi * 900 * (i / SR)) * 0.4 * env(i, n, 0.002, 0.5) for i in range(n)]

write("whack.wav", whack())
write("pop.wav", pop())
write("question.wav", question())
write("miss.wav", miss())
write("fail.wav", fail())
write("start.wav", start())
write("tick.wav", tick())
