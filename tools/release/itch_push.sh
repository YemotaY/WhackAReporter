#!/usr/bin/env bash
# Pushes exports to itch.io with butler.
#
#   itch_push.sh            push every artefact found in export/v$VERSION
#   itch_push.sh web        push only the html5 channel
#
# Needs: ITCH_TARGET in .env ("user/game") and the API key in
# secrets/itch_api_key (https://itch.io/user/settings/api-keys).
. "$(dirname "$0")/common.sh"

[[ -n "${ITCH_TARGET:-}" ]] || die "ITCH_TARGET not set in .env (e.g. yemotay/whack-a-reporter)"
[[ -f "$SECRETS/itch_api_key" ]] || die "secrets/itch_api_key missing - paste your itch.io API key into it"
BUTLER_API_KEY="$(tr -d '[:space:]' < "$SECRETS/itch_api_key")"
export BUTLER_API_KEY

BUTLER="$BUILD/bin/butler"
if [[ ! -x "$BUTLER" ]]; then
	log "installing butler into build/bin"
	mkdir -p "$BUILD/bin"
	curl -fL --retry 3 -o "$BUILD/butler.zip" \
		"https://broth.itch.zone/butler/linux-amd64/LATEST/archive/default"
	python3 -c 'import sys,zipfile;zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$BUILD/butler.zip" "$BUILD/bin"
	chmod +x "$BUTLER"
	rm -f "$BUILD/butler.zip"
fi
"$BUTLER" -V >/dev/null || die "butler is not runnable"

push() { # channel path
	[[ -e "$2" ]] || { warn "skipping $1 (nothing at ${2#"$ROOT"/})"; return; }
	log "butler push $1 <- ${2#"$ROOT"/}"
	"$BUTLER" push --userversion "$VERSION" "$2" "$ITCH_TARGET:$1"
}

case "${1:-all}" in
	web)     push html5 "$EXPORT_DIR/web" ;;
	linux)   push linux "$EXPORT_DIR/linux" ;;
	windows) push windows "$EXPORT_DIR/windows" ;;
	android) push android "$EXPORT_DIR/android" ;;
	all)
		push html5   "$EXPORT_DIR/web"
		push linux   "$EXPORT_DIR/linux"
		push windows "$EXPORT_DIR/windows"
		push android "$EXPORT_DIR/android"
		;;
	*) die "usage: itch_push.sh [web|linux|windows|android|all]" ;;
esac
log "done - check https://$(cut -d/ -f1 <<<"$ITCH_TARGET").itch.io/$(cut -d/ -f2 <<<"$ITCH_TARGET")"
