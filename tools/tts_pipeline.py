#!/usr/bin/env python3
"""Neural TTS pipeline for Whack-A-Reporter (Piper).

Reads assets/voice/dialogue.json and synthesizes:
  - every entry in "lines"        -> assets/voice/<key>.wav
  - every entry in "qa"           -> assets/voice/qa_<id>_q.wav (reporter)
                                     assets/voice/qa_<id>_a.wav (president)

Voices (Piper, https://huggingface.co/rhasspy/piper-voices):
  president  en_US-hfc_male-medium, slowed & pompous (length-scale 1.15)
  reporter1  en_US-joe-medium (urgent male)
  reporter2  en_US-hfc_female-medium (urgent female)

Setup (once):
  sudo pacman -S python-pip
  python3 -m venv ~/.local/share/piper-venv
  ~/.local/share/piper-venv/bin/pip install piper-tts
  # model download: see MODEL_DIR below / README

Usage:  python3 tools/tts_pipeline.py
Falls back to espeak-ng if Piper or its models are unavailable.
"""
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VOICE_DIR = os.path.join(ROOT, "assets", "voice")
DIALOGUE = os.path.join(VOICE_DIR, "dialogue.json")
PIPER_BIN = os.path.expanduser("~/.local/share/piper-venv/bin/piper")
MODEL_DIR = os.path.expanduser("~/.local/share/piper-voices")

PIPER_VOICES = {
    "president_de": {"model": "de_DE-thorsten-medium.onnx", "length_scale": "1.15"},
    "reporter1_de": {"model": "de_DE-pavoque-low.onnx", "length_scale": "0.95"},
    "reporter2_de": {"model": "de_DE-eva_k-x_low.onnx", "length_scale": "0.95"},
    "president_fr": {"model": "fr_FR-gilles-low.onnx", "length_scale": "1.15"},
    "reporter1_fr": {"model": "fr_FR-siwis-medium.onnx", "length_scale": "0.95"},
    "reporter2_fr": {"model": "fr_FR-tom-medium.onnx", "length_scale": "0.95"},
    "president_en": {"model": "en_US-hfc_male-medium.onnx", "length_scale": "1.15"},
    "reporter1_en": {"model": "en_US-joe-medium.onnx", "length_scale": "0.95"},
    "reporter2_en": {"model": "en_US-hfc_female-medium.onnx", "length_scale": "0.95"},
}
ESPEAK_VOICES = {
    "president_de": ["-v", "en-us+m1", "-p", "15", "-s", "125", "-a", "190"],
    "reporter1_de": ["-v", "en-us+m4", "-p", "60", "-s", "180", "-a", "160"],
    "reporter2_de": ["-v", "en-us+f3", "-p", "65", "-s", "185", "-a", "160"],
    "president_fr": ["-v", "en-us+m1", "-p", "15", "-s", "125", "-a", "190"],
    "reporter1_fr": ["-v", "en-us+m4", "-p", "60", "-s", "180", "-a", "160"],
    "reporter2_fr": ["-v", "en-us+f3", "-p", "65", "-s", "185", "-a", "160"],
    "president_en": ["-v", "en-us+m1", "-p", "15", "-s", "125", "-a", "190"],
    "reporter1_en": ["-v", "en-us+m4", "-p", "60", "-s", "180", "-a", "160"],
    "reporter2_en": ["-v", "en-us+f3", "-p", "65", "-s", "185", "-a", "160"],
}


def piper_available() -> bool:
    return os.path.exists(PIPER_BIN) and all(
        os.path.exists(os.path.join(MODEL_DIR, v["model"])) for v in PIPER_VOICES.values()
    )


def synth_piper(text: str, speaker: str, out_path: str) -> None:
    cfg = PIPER_VOICES[speaker]
    subprocess.run(
        [
            PIPER_BIN,
            "-m", os.path.join(MODEL_DIR, cfg["model"]),
            "--length-scale", cfg["length_scale"],
            "--sentence-silence", "0.25",
            "-f", out_path,
        ],
        input=text.encode(),
        check=True
    )


def synth_espeak(text: str, speaker: str, out_path: str) -> None:
    subprocess.run(
        ["espeak-ng", *ESPEAK_VOICES[speaker], "-w", out_path, text],
        check=True,
    )


def main() -> int:
    if piper_available():
        synth, engine = synth_piper, "piper"
    elif shutil.which("espeak-ng"):
        synth, engine = synth_espeak, "espeak-ng (fallback)"
    else:
        print("ERROR: neither Piper nor espeak-ng available.", file=sys.stderr)
        return 1
    print(f"engine: {engine}")

    with open(DIALOGUE, encoding="utf-8") as f:
        data = json.load(f)

    jobs = []

    for i in range(0,len(data)):
        #list(data[i].keys())[0] -> language key
        print(i)
        lang = list(data[i].keys())[0]
        print(lang)
        for key, line in data[i][list(data[i].keys())[0]]["lines"].items():
            print("key/line:" + line["speaker"]+"_"+lang)
            jobs.append((line["text"], line["speaker"]+"_"+lang, f"{key}_{lang}.wav"))
        for qa in data[i][list(data[i].keys())[0]]["qa"]:
            print("qa:"+str(qa["question"]["speaker"])+"_"+lang)
            jobs.append((qa["question"]["text"], str(qa["question"]["speaker"])+"_"+lang, f"qa_{qa['id']}_{lang}_q.wav"))
            jobs.append((qa["answer"]["text"], str(qa["answer"]["speaker"])+"_"+lang, f"qa_{qa['id']}_{lang}_a.wav"))

        for text, speaker, fname in jobs:
            out = os.path.join(VOICE_DIR, lang ,fname)
            synth(text.replace("\n",""), speaker, out)
            print(f"wrote assets/voice/{lang}/{fname}  [{speaker}]")
    print("done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
