#!/usr/bin/env python3
"""Set keys in the Godot editor settings file (headless-friendly).

usage: editor_settings.py <major.minor> key=value [key=value ...]

Values are written as Godot strings. Used by the release pipeline to point the
Android exporter at build/android-sdk and build/jdk without a GUI.
"""
import os
import re
import sys


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    ver = sys.argv[1]
    cfg_dir = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    path = os.path.join(cfg_dir, "godot", f"editor_settings-{ver}.tres")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        text = open(path, encoding="utf-8").read()
    else:
        text = '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    if "[resource]" not in text:
        text += "\n[resource]\n"
    for kv in sys.argv[2:]:
        key, _, value = kv.partition("=")
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        line = f'{key} = "{escaped}"'
        pattern = re.compile(rf"^{re.escape(key)}\s*=.*$", re.M)
        if pattern.search(text):
            text = pattern.sub(line, text, count=1)
        else:
            text = text.rstrip("\n") + "\n" + line + "\n"
    open(path, "w", encoding="utf-8").write(text)
    print(f"updated {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
