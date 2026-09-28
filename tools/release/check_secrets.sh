#!/usr/bin/env bash
# Refuses to let secrets reach git. Runs as the pre-commit hook and via
# `make check-secrets` (which additionally scans everything already tracked).
#
#   check_secrets.sh            scan staged changes (pre-commit mode)
#   check_secrets.sh --all      scan every tracked file + the index
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail=0
red() { printf '\033[1;31m[secrets] %s\033[0m\n' "$*" >&2; fail=1; }

# 1. Paths that must never be tracked.
FORBIDDEN_PATHS='^(secrets/|build/|export/|\.godot/|\.env$|.*export_credentials\.cfg$|.*\.(key|pem|p12|pfx|keystore|jks|mobileprovision|gd\.map)$|.*override\.cfg$)'
if [[ "${1:-}" == "--all" ]]; then
	files="$(git ls-files)"
else
	files="$(git diff --cached --name-only --diff-filter=ACMR)"
fi
while IFS= read -r f; do
	[[ -z "$f" ]] && continue
	if [[ "$f" =~ $FORBIDDEN_PATHS ]]; then
		red "forbidden path staged/tracked: $f"
	fi
done <<<"$files"

# 2. The actual encryption key (or any 64-hex blob that equals it) in content.
key=""
[[ -f secrets/encryption.key ]] && key="$(tr -d '[:space:]' < secrets/encryption.key | tr 'A-F' 'a-f')"
# 3. Generic secret-looking content.
PATTERNS=(
	'script_encryption_key="[0-9a-fA-F]{64}"'
	'GODOT_SCRIPT_ENCRYPTION_KEY=[0-9a-fA-F]{64}'
	'SCRIPT_AES256_ENCRYPTION_KEY=[0-9a-fA-F]{64}'
	'BUTLER_API_KEY=[A-Za-z0-9]{20,}'
	'keystore/(release|debug)_password="[^"]+"'
	'-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----'
	'AKIA[0-9A-Z]{16}'
	'ghp_[A-Za-z0-9]{36}'
)
content_of() { # file -> streams staged (index) or working-tree content
	if [[ "${1:-}" == "--all" ]]; then cat "$2"; else git show ":$2" 2>/dev/null || cat "$2"; fi
}
while IFS= read -r f; do
	[[ -z "$f" || ! -f "$f" ]] && continue
	# Binary assets (wav, png, .so ...) cannot carry our text secrets; skip them.
	if content_of "${1:-}" "$f" | head -c 8000 | LC_ALL=C grep -qP '\x00'; then continue; fi
	if [[ -n "$key" ]] && content_of "${1:-}" "$f" | grep -qiF -- "$key"; then
		red "PCK encryption key found in $f"
	fi
	for p in "${PATTERNS[@]}"; do
		if content_of "${1:-}" "$f" | grep -qE -- "$p"; then
			red "secret-looking content in $f (pattern: $p)"
		fi
	done
done <<<"$files"

if [[ $fail -ne 0 ]]; then
	red "commit blocked. Move secrets to secrets/ (git-ignored) or fix .gitignore."
	exit 1
fi
printf '\033[1;32m[secrets] clean\033[0m\n'
