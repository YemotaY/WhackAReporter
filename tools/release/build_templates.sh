#!/usr/bin/env bash
# Compiles hardened Godot export templates from build/godot with the PCK
# encryption key baked in, then installs them where the Godot editor looks
# for them (so every export - CLI or GUI - can only run encrypted PCKs).
#
#   build_templates.sh linux|windows|web|android|ios|all
#
# Flags: production=yes (LTO, no debug symbols, optimisations), release only.
. "$(dirname "$0")/common.sh"

load_key
[[ -x "$VENV/bin/scons" && -d "$GODOT_SRC" ]] || die "run 'make setup' first"
mkdir -p "$TEMPLATES_DIR" "$TEMPLATES_OUT"
echo "$GODOT_VER" > "$TEMPLATES_DIR/version.txt"

# disable_overrides:      shipped binaries ignore override.cfg (no re-enabling
#                         stderr / tweaking settings from outside the PCK)
# disable_path_overrides: (default on for templates) no --main-pack / -s /
#                         scene args, so the key-bearing binary can't be used
#                         as a generic runner for foreign PCKs or scripts.
COMMON=(target=template_release production=yes debug_symbols=no disable_overrides=yes "-j$JOBS")

install_template() { # src dst-name
	[[ -f "$1" ]] || die "expected build output missing: $1"
	cp -f "$1" "$TEMPLATES_OUT/$2"
	cp -f "$1" "$TEMPLATES_DIR/$2"
	log "installed $2 -> $TEMPLATES_DIR ($(du -h "$1" | cut -f1))"
}

build_linux() {
	log "building Linux x86_64 template"
	(cd "$GODOT_SRC" && scons platform=linuxbsd arch=x86_64 "${COMMON[@]}")
	local out="$GODOT_SRC/bin/godot.linuxbsd.template_release.x86_64"
	strip --strip-all "$out" 2>/dev/null || true
	install_template "$out" "$(template_file linux)"
}

# Same engine/key/optimisation as the release template, but keeps `-s` and
# override.cfg so the obfuscated build can run tests/smoke_test.gd headlessly.
# Only referenced by the "Linux Test" preset; never shipped.
build_linux_test() {
	log "building Linux x86_64 TEST template (path overrides enabled)"
	(cd "$GODOT_SRC" && scons platform=linuxbsd arch=x86_64 target=template_release production=yes \
		debug_symbols=no disable_path_overrides=no extra_suffix=test "-j$JOBS")
	local out="$GODOT_SRC/bin/godot.linuxbsd.template_release.x86_64.test"
	[[ -f "$out" ]] || die "expected build output missing: $out"
	cp -f "$out" "$TEMPLATES_OUT/linux_release_test.x86_64"
	log "installed linux_release_test.x86_64 -> $TEMPLATES_OUT"
}

build_windows() {
	local mingw="$BUILD/llvm-mingw"
	[[ -x "$mingw/bin/x86_64-w64-mingw32-clang" ]] || die "run 'make setup-windows' first"
	log "building Windows x86_64 template (llvm-mingw)"
	# Game renders with GL Compatibility; skip D3D12/WinRT/AccessKit deps that
	# would otherwise have to be downloaded into the source tree.
	(cd "$GODOT_SRC" && PATH="$mingw/bin:$PATH" scons platform=windows arch=x86_64 \
		use_mingw=yes use_llvm=yes mingw_prefix="$mingw" d3d12=no winrt=no accesskit=no "${COMMON[@]}")
	local out="$GODOT_SRC/bin/godot.windows.template_release.x86_64.llvm.exe"
	[[ -f "$out" ]] || out="$GODOT_SRC/bin/godot.windows.template_release.x86_64.exe"
	"$mingw/bin/x86_64-w64-mingw32-strip" --strip-all "$out" 2>/dev/null || true
	install_template "$out" "$(template_file windows)"
	# Console wrapper is only used if debug/export_console_wrapper != 0.
	local con="${out%.exe}.console.exe"
	[[ -f "$con" ]] && install_template "$con" "windows_release_x86_64_console.exe" || true
}

build_web() {
	[[ -f "$BUILD/emsdk/emsdk_env.sh" ]] || die "run 'make setup-web' first"
	log "building Web (wasm32, no threads - itch.io friendly) template"
	# shellcheck disable=SC1091
	(cd "$GODOT_SRC" && . "$BUILD/emsdk/emsdk_env.sh" >/dev/null 2>&1 \
		&& scons platform=web threads=no "${COMMON[@]}")
	install_template "$GODOT_SRC/bin/godot.web.template_release.wasm32.nothreads.zip" "$(template_file web)"
}

build_android() {
	export JAVA_HOME="$BUILD/jdk" ANDROID_HOME="$BUILD/android-sdk"
	[[ -x "$JAVA_HOME/bin/java" && -d "$ANDROID_HOME/ndk" ]] || die "run 'make setup-android' first"
	# gradle re-invokes scons per ABI and resolves it from PATH, so the venv's
	# scons (and the JDK) must be discoverable there.
	export PATH="$JAVA_HOME/bin:$VENV/bin:$PATH"
	log "building Android arm64 template"
	(cd "$GODOT_SRC" && scons platform=android arch=arm64 "${COMMON[@]}")
	log "packaging Android templates with gradle"
	(cd "$GODOT_SRC/platform/android/java" && ./gradlew --no-daemon -q generateGodotTemplates)
	install_template "$GODOT_SRC/bin/android_release.apk" "$(template_file android)"
	install_template "$GODOT_SRC/bin/android_source.zip" "android_source.zip"
	# gradle leaves a debug apk too if debug libs exist; harmless if absent.
	[[ -f "$GODOT_SRC/bin/android_debug.apk" ]] && cp -f "$GODOT_SRC/bin/android_debug.apk" "$TEMPLATES_DIR/" || true
}

build_ios() {
	[[ "$(uname)" == Darwin ]] || die "iOS templates must be compiled on macOS (Xcode SDK). Copy this repo + secrets/encryption.key to a Mac and run 'make templates-ios' there, then copy build/templates/ios.zip into $TEMPLATES_DIR"
	need_cmd xcodebuild "Xcode"
	log "building iOS arm64 device + simulator templates"
	(cd "$GODOT_SRC" && scons platform=ios arch=arm64 "${COMMON[@]}" \
		&& scons platform=ios arch=arm64 ios_simulator=yes "${COMMON[@]}" \
		&& scons platform=ios arch=x86_64 ios_simulator=yes "${COMMON[@]}")
	local b="$GODOT_SRC/bin" stage="$BUILD/ios_stage"
	rm -rf "$stage" && mkdir -p "$stage"
	cp -r "$GODOT_SRC/misc/dist/ios_xcode/." "$stage/"
	lipo -create "$b/libgodot.ios.template_release.arm64.simulator.a" \
		"$b/libgodot.ios.template_release.x86_64.simulator.a" \
		-output "$b/libgodot.ios.template_release.simulator.a"
	xcodebuild -create-xcframework \
		-library "$b/libgodot.ios.template_release.arm64.a" \
		-library "$b/libgodot.ios.template_release.simulator.a" \
		-output "$stage/libgodot.ios.release.xcframework"
	(cd "$stage" && rm -f "$b/ios.zip" && zip -q -r -9 "$b/ios.zip" .)
	install_template "$b/ios.zip" "$(template_file ios)"
}

case "${1:-}" in
	linux)      build_linux ;;
	linux-test) build_linux_test ;;
	windows)    build_windows ;;
	web)        build_web ;;
	android)    build_android ;;
	ios)        build_ios ;;
	all)        build_linux; build_linux_test; build_windows; build_web; build_android ;;
	*) die "usage: build_templates.sh linux|linux-test|windows|web|android|ios|all" ;;
esac
