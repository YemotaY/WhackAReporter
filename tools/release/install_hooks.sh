#!/usr/bin/env bash
# Installs the pre-commit secret scanner into .git/hooks (idempotent).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
hook="$ROOT/.git/hooks/pre-commit"
[[ -d "$ROOT/.git" ]] || { echo "[hooks] not a git checkout, skipping"; exit 0; }
mkdir -p "$ROOT/.git/hooks"
cat > "$hook" <<'EOF'
#!/usr/bin/env bash
# Installed by tools/release/install_hooks.sh - blocks commits containing secrets.
exec "$(git rev-parse --show-toplevel)/tools/release/check_secrets.sh"
EOF
chmod +x "$hook"
echo "[hooks] pre-commit secret scan installed"
