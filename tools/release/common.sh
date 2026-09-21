#!/usr/bin/env bash
# Shared helpers for the release pipeline. Source this, do not execute it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="$ROOT/build"
SECRETS="$ROOT/secrets"
GODOT_SRC="$BUILD/godot"
TEMPLATES_OUT="$BUILD/templates"
VENV="$BUILD/venv"

# Optional per-machine config (git-ignored).
if [[ -f "$ROOT/.env" ]]; then
	set -a
	# shellcheck disable=SC1091
	. "$ROOT/.env"
	set +a
fi

GODOT_BIN="${GODOT_BIN:-godot}"
VERSION="${VERSION:-1.0.0}"
JOBS="${JOBS:-$(nproc)}"
EXPORT_DIR="$ROOT/export/v$VERSION"
APP_NAME="Whack-A-Reporter"

log()  { printf '\033[1;34m[release]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[release] WARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[release] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1 ($2)"; }

# Godot version string, e.g. "4.7.2.stable", and matching git tag "4.7.2-stable".
godot_version() {
	need_cmd "$GODOT_BIN" "install Godot 4 or set GODOT_BIN"
	"$GODOT_BIN" --version 2>/dev/null | tail -n1 | cut -d. -f1-4
}
GODOT_VER="${GODOT_VER:-$(godot_version)}"
GODOT_TAG="${GODOT_TAG:-${GODOT_VER%.stable}-stable}"
TEMPLATES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$GODOT_VER"

# Loads secrets/encryption.key into the env vars understood by
#   * SCons  (SCRIPT_AES256_ENCRYPTION_KEY  -> baked into export templates)
#   * Godot  (GODOT_SCRIPT_ENCRYPTION_KEY   -> used when exporting the PCK)
load_key() {
	[[ -f "$SECRETS/encryption.key" ]] || die "secrets/encryption.key missing - run 'make setup'"
	local key
	key="$(tr -d '[:space:]' < "$SECRETS/encryption.key")"
	[[ "$key" =~ ^[0-9a-fA-F]{64}$ ]] || die "secrets/encryption.key must be 64 hex chars (256-bit)"
	export SCRIPT_AES256_ENCRYPTION_KEY="${key,,}"
	export GODOT_SCRIPT_ENCRYPTION_KEY="${key,,}"
}

scons() { "$VENV/bin/scons" "$@"; }

# Canonical template file names Godot looks for in TEMPLATES_DIR.
template_file() {
	case "$1" in
		linux)   echo "linux_release.x86_64" ;;
		windows) echo "windows_release_x86_64.exe" ;;
		web)     echo "web_nothreads_release.zip" ;;
		android) echo "android_release.apk" ;;
		ios)     echo "ios.zip" ;;
		macos)   echo "macos.zip" ;;
		*) die "unknown platform: $1" ;;
	esac
}

preset_name() {
	case "$1" in
		linux)   echo "Linux" ;;
		windows) echo "Windows Desktop" ;;
		web)     echo "Web" ;;
		android) echo "Android" ;;
		ios)     echo "iOS" ;;
		macos)   echo "macOS" ;;
		test)    echo "Linux Test" ;;
		*) die "unknown platform: $1" ;;
	esac
}

require_template() {
	local f
	if [[ "$1" == test ]]; then
		f="$TEMPLATES_OUT/linux_release_test.x86_64"
	else
		f="$TEMPLATES_DIR/$(template_file "$1")"
	fi
	[[ -f "$f" ]] || die "export template missing: $f  -> run 'make templates-${1/test/linux}'"
}

# Godot's editor writes a git-ignored credentials file; keep it in sync with
# secrets/ so GUI exports use the same key as CLI exports.
sync_credentials() {
	load_key
	local creds="$ROOT/.godot/export_credentials.cfg"
	mkdir -p "$ROOT/.godot"
	local n
	n="$(grep -c '^\[preset\.[0-9]*\]$' "$ROOT/export_presets.cfg")"
	{
		for ((i = 0; i < n; i++)); do
			printf '[preset.%d]\n\nscript_encryption_key="%s"\n\n' "$i" "$GODOT_SCRIPT_ENCRYPTION_KEY"
		done
	} > "$creds"
	chmod 600 "$creds"
	log "synced .godot/export_credentials.cfg ($n presets)"
}
