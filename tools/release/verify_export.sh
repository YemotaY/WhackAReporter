#!/usr/bin/env bash
# Post-export checks. Proves the shipped artefact is encrypted + obfuscated and
# (for Linux) that the obfuscated build still boots and passes the gameplay
# smoke test.
#
#   verify_export.sh linux|windows|web|android|test|all
. "$(dirname "$0")/common.sh"

# Identifiers that exist verbatim in the source. None may survive in a release
# artefact: encryption hides them, and GDMaim renames them before encryption.
PLAINTEXT_MARKERS=(
	"_spawn_reporter" "add_leaderboard_entry" "_qualifies_for_board"
	"res://scripts/main.gd" "res://scenes/main.tscn" "BriefingRoomBG"
	"question_duration" "hole_qa"
)

fail=0
ok()   { printf '  \033[1;32mPASS\033[0m %s\n' "$*"; }
bad()  { printf '  \033[1;31mFAIL\033[0m %s\n' "$*"; fail=1; }

check_no_plaintext() { # file...
	local f m hits
	for f in "$@"; do
		[[ -f "$f" ]] || { bad "missing artefact $f"; continue; }
		hits=""
		for m in "${PLAINTEXT_MARKERS[@]}"; do
			if grep -q -F -a -- "$m" "$f"; then hits="$hits $m"; fi
		done
		if [[ -z "$hits" ]]; then
			ok "no source identifiers/paths leak from $(basename "$f")"
		else
			bad "plaintext found in $(basename "$f"):$hits"
		fi
	done
}

check_pck_header() { # file
	# Encrypted directory => the "GDPC" magic is still present (needed by the
	# loader) but the PCK_DIR_ENCRYPTED flag (bit 0) is set in the header.
	local f="$1"
	python3 - "$f" <<'PY' && ok "PCK directory flagged encrypted in $(basename "$1")" || bad "PCK directory NOT encrypted in $(basename "$1")"
import struct, sys
data = open(sys.argv[1], "rb").read()
i = -1
while True:
    i = data.find(b"GDPC", i + 1)
    if i < 0 or i + 24 > len(data):
        sys.exit(1)
    # magic, pack format version, engine major/minor/patch, flags
    fmt, major, minor, patch, flags = struct.unpack_from("<IIIII", data, i + 4)
    if 2 <= fmt <= 16 and major == 4 and minor < 100 and patch < 100:
        break
sys.exit(0 if flags & 1 else 1)
PY
}

run_headless() { # binary [args...] -> test template honours override.cfg, so re-enable output
	local bin="$1"; shift
	local dir; dir="$(dirname "$bin")"
	printf '[application]\nrun/disable_stdout=false\nrun/disable_stderr=false\nrun/flush_stdout_on_print=true\n' > "$dir/override.cfg"
	local out rc=0
	out="$(cd "$dir" && timeout 180 "$bin" --headless "$@" 2>&1)" || rc=$?
	rm -f "$dir/override.cfg"
	printf '%s' "$out"
	return $rc
}

verify_linux() {
	local bin="$EXPORT_DIR/linux/$APP_NAME.x86_64"
	log "verifying Linux export"
	[[ -x "$bin" ]] || { bad "missing $bin"; return; }
	check_no_plaintext "$bin"
	check_pck_header "$bin"
	# Release template ignores override.cfg / -s by design, so only the exit
	# code is observable here; behaviour is covered by verify_test_build.
	local rc=0
	(cd "$(dirname "$bin")" && timeout 120 "$bin" --headless --quit-after 120 >/dev/null 2>&1) || rc=$?
	if [[ $rc -eq 0 ]]; then
		ok "release binary boots headless (120 frames) and exits cleanly"
	else
		bad "release binary failed headless boot (rc=$rc)"
	fi
	# Tamper resistance: with path overrides compiled out, `-s <script>` is
	# silently dropped and the real game runs (rc 0). With overrides enabled the
	# missing script would be fatal (rc 1).
	rc=0
	(cd "$(dirname "$bin")" && timeout 60 "$bin" --headless -s res://tests/smoke_test.gd --quit-after 5 >/dev/null 2>&1) || rc=$?
	if [[ $rc -eq 0 ]]; then
		ok "release binary ignores -s/--main-pack/--path (path overrides compiled out)"
	else
		bad "release binary honoured a CLI script override (rc=$rc) - built without disable_path_overrides?"
	fi
}

verify_test_build() {
	local bin="$BUILD/test_export/$APP_NAME-test.x86_64"
	local pck="$BUILD/test_export/$APP_NAME-test.pck"
	log "verifying obfuscated gameplay smoke test build"
	[[ -x "$bin" ]] || { bad "missing $bin (run 'make export-test')"; return; }
	check_no_plaintext "$pck"
	check_pck_header "$pck"
	local out rc=0
	out="$(run_headless "$bin" -s res://tests/smoke_test.gd)" || rc=$?
	if [[ $rc -eq 0 ]] && grep -q "ALL SMOKE TESTS PASSED" <<<"$out" && ! grep -qE 'SCRIPT ERROR|FAIL:' <<<"$out"; then
		ok "obfuscated+encrypted build passes gameplay smoke test"
	else
		bad "smoke test failed inside obfuscated build (rc=$rc)"; printf '%s\n' "$out" | tail -n 40
	fi
}

verify_windows() {
	local exe="$EXPORT_DIR/windows/$APP_NAME.exe"
	log "verifying Windows export"
	[[ -f "$exe" ]] || { bad "missing $exe"; return; }
	check_no_plaintext "$exe"
	check_pck_header "$exe"
	head -c 2 "$exe" | grep -q "MZ" && ok "PE header present" || bad "not a PE executable"
}

verify_web() {
	local d="$EXPORT_DIR/web"
	log "verifying Web export"
	[[ -f "$d/index.html" && -f "$d/index.pck" && -f "$d/index.wasm" ]] || { bad "web export incomplete"; return; }
	check_no_plaintext "$d/index.pck"
	check_pck_header "$d/index.pck"
	local z="$EXPORT_DIR/$APP_NAME-web-v$VERSION.zip"
	if python3 -c 'import sys,zipfile;z=zipfile.ZipFile(sys.argv[1]);sys.exit(0 if "index.html" in z.namelist() else 1)' "$z"; then
		ok "itch.io zip has index.html at root"
	else
		bad "itch.io zip missing/invalid"
	fi
}

verify_android() {
	local apk="$EXPORT_DIR/android/$APP_NAME-v$VERSION.apk"
	log "verifying Android export"
	[[ -f "$apk" ]] || { bad "missing $apk"; return; }
	# APK exports store the game as an embedded .pck OR (with encrypt_directory)
	# as individually AES-encrypted, hash-named blobs under assets/. Handle both.
	local markers="${PLAINTEXT_MARKERS[*]}"
	if PLAINTEXT_MARKERS="$markers" python3 - "$apk" <<'PY'
import os, re, sys, math, zipfile, struct
apk = sys.argv[1]
markers = [m.encode() for m in os.environ["PLAINTEXT_MARKERS"].split()]
z = zipfile.ZipFile(apk)
names = z.namelist()
pcks = [n for n in names if n.endswith(".pck")]
blobs = [n for n in names if re.fullmatch(r"assets/[0-9a-f]{64}", n)]
leaks = []; res = 0; min_ent = 8.0; data_files = pcks or blobs
if not data_files:
    print("no game data (.pck or encrypted assets) inside apk"); sys.exit(1)
for n in data_files:
    d = z.read(n)
    res += d.count(b"res://")
    for m in markers:
        if m in d:
            leaks.append((m.decode(), n))
    if len(d) >= 4096:  # entropy only meaningful on sizeable blobs
        import collections
        c = collections.Counter(d)
        ent = -sum(v/len(d)*math.log2(v/len(d)) for v in c.values())
        min_ent = min(min_ent, ent)
if leaks:
    print("plaintext markers leaked:", leaks); sys.exit(1)
if res:
    print(f"{res} res:// path(s) leaked in cleartext"); sys.exit(1)
if pcks:
    # embedded pck: assert the encrypted-directory flag
    d = z.read(pcks[0]); i = d.find(b"GDPC")
    flags = struct.unpack_from("<I", d, i + 20)[0] if i >= 0 else 0
    if not (flags & 1):
        print("embedded PCK directory NOT encrypted"); sys.exit(1)
    print(f"embedded PCK present, directory encrypted, no leaks")
else:
    if min_ent < 7.5:
        print(f"game assets not encrypted (entropy {min_ent:.2f} < 7.5)"); sys.exit(1)
    print(f"{len(blobs)} game assets individually encrypted (min entropy {min_ent:.2f}/8.0), no leaks")
PY
	then ok "Android game data encrypted, no source identifiers/paths leak"
	else bad "Android game data check failed"; fi
	if python3 -c 'import sys,zipfile;n=zipfile.ZipFile(sys.argv[1]).namelist();sys.exit(0 if any(x.startswith("META-INF/") and x.endswith((".RSA",".EC",".SF")) for x in n) else 1)' "$apk"; then
		ok "apk is signed"
	else
		bad "apk is not signed"
	fi
}

case "${1:-all}" in
	linux)   verify_linux ;;
	test)    verify_test_build ;;
	windows) verify_windows ;;
	web)     verify_web ;;
	android) verify_android ;;
	all)
		[[ -e "$EXPORT_DIR/linux" ]]   && verify_linux
		[[ -e "$BUILD/test_export" ]]  && verify_test_build
		[[ -e "$EXPORT_DIR/windows" ]] && verify_windows
		[[ -e "$EXPORT_DIR/web" ]]     && verify_web
		[[ -e "$EXPORT_DIR/android" ]] && verify_android
		;;
	*) die "usage: verify_export.sh linux|test|windows|web|android|all" ;;
esac
[[ $fail -eq 0 ]] && log "verification passed" || die "verification FAILED"
