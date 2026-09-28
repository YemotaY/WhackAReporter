#!/usr/bin/env bash
# Exports the game for one platform using the hardened templates.
#
#   export.sh linux|windows|web|android|ios|macos|test
#
# Output: export/v$VERSION/<platform>/...   (test -> build/test_export/)
. "$(dirname "$0")/common.sh"

platform="${1:-}"
[[ -n "$platform" ]] && preset="$(preset_name "$platform")"
load_key
[[ -f "$ROOT/.godot/export_credentials.cfg" ]] || sync_credentials

export_with_godot() { # preset out-path
	mkdir -p "$(dirname "$2")"
	log "exporting preset '$1' -> ${2#"$ROOT"/}"
	local logf="$BUILD/export_${platform}.log"
	# The editor must import once so .godot/imported exists in headless mode.
	"$GODOT_BIN" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
	if ! "$GODOT_BIN" --headless --path "$ROOT" --export-release "$1" "$2" > "$logf" 2>&1; then
		cat "$logf" >&2
		die "godot export failed (see $logf)"
	fi
	if grep -qiE 'ERROR|failed|Parse Error' "$logf"; then
		grep -iE 'ERROR|failed|Parse Error' "$logf" >&2
		die "export log contains errors (see $logf)"
	fi
	[[ -e "$2" ]] || die "export produced no output at $2"
	log "export OK: $(du -sh "$2" | cut -f1)"
}

case "$platform" in
	linux)
		require_template linux
		out="$EXPORT_DIR/linux/$APP_NAME.x86_64"
		export_with_godot "$preset" "$out"
		chmod +x "$out"
		;;
	windows)
		require_template windows
		export_with_godot "$preset" "$EXPORT_DIR/windows/$APP_NAME.exe"
		;;
	web)
		require_template web
		out="$EXPORT_DIR/web/index.html"
		rm -rf "$EXPORT_DIR/web"
		export_with_godot "$preset" "$out"
		# itch.io wants a zip with index.html at the root.
		(cd "$EXPORT_DIR/web" && rm -f "../$APP_NAME-web-v$VERSION.zip" \
			&& python3 -c 'import sys,zipfile,os
z=zipfile.ZipFile(sys.argv[1],"w",zipfile.ZIP_DEFLATED)
[z.write(f) for f in sorted(os.listdir(".")) if os.path.isfile(f)]
z.close()' "../$APP_NAME-web-v$VERSION.zip")
		log "itch.io bundle: export/v$VERSION/$APP_NAME-web-v$VERSION.zip"
		;;
	android)
		require_template android
		ks="$SECRETS/android_release.keystore"
		[[ -f "$ks" && -f "$ks.pass" ]] || die "Android keystore missing - run 'make setup-android'"
		export JAVA_HOME="$BUILD/jdk" ANDROID_HOME="$BUILD/android-sdk"
		export PATH="$JAVA_HOME/bin:$PATH"
		# Godot reads these instead of storing credentials in the preset.
		export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$ks"
		export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${ANDROID_KEY_ALIAS:-whackareporter}"
		export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(cat "$ks.pass")"
		export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$SECRETS/android_debug.keystore"
		export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
		export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"
		# The exporter reads SDK/JDK locations from editor settings, not env.
		"$GODOT_BIN" --headless -e --quit --path "$ROOT" >/dev/null 2>&1 || true
		python3 "$ROOT/tools/release/editor_settings.py" "$(echo "$GODOT_VER" | cut -d. -f1-2)" \
			"export/android/android_sdk_path=$ANDROID_HOME" \
			"export/android/java_sdk_path=$JAVA_HOME" >/dev/null
		export_with_godot "$preset" "$EXPORT_DIR/android/$APP_NAME-v$VERSION.apk"
		;;
	ios)
		require_template ios
		export_with_godot "$preset" "$EXPORT_DIR/ios/$APP_NAME.xcodeproj"
		log "open export/v$VERSION/ios in Xcode on macOS to sign & archive the .ipa"
		;;
	macos)
		require_template macos
		export_with_godot "$preset" "$EXPORT_DIR/macos/$APP_NAME.zip"
		;;
	test)
		require_template test
		out="$BUILD/test_export/$APP_NAME-test.x86_64"
		rm -rf "$BUILD/test_export"
		export_with_godot "$preset" "$out"
		chmod +x "$out"
		;;
	*) die "usage: export.sh linux|windows|web|android|ios|macos|test" ;;
esac
