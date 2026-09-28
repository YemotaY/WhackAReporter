#!/usr/bin/env bash
# Installs everything the pipeline needs into build/ (no root required).
#
#   setup.sh base      venv + SCons, Godot source checkout, secrets/, hooks
#   setup.sh windows   llvm-mingw cross toolchain
#   setup.sh web       emsdk (pinned to the version Godot CI uses)
#   setup.sh android   JDK 17 + Android SDK/NDK + release keystore
#   setup.sh all
. "$(dirname "$0")/common.sh"

fetch() { # url dest
	log "downloading $(basename "$2")"
	curl -fL --retry 3 --progress-bar -o "$2" "$1"
}

setup_base() {
	need_cmd python3 "python 3"
	need_cmd git "git"
	need_cmd curl "curl"
	mkdir -p "$BUILD" "$SECRETS" "$TEMPLATES_OUT" "$ROOT/export"
	chmod 700 "$SECRETS"
	# Keep the Godot editor from scanning/importing these trees.
	for d in "$BUILD" "$SECRETS" "$ROOT/export"; do
		[[ -f "$d/.gdignore" ]] || : > "$d/.gdignore"
	done

	if [[ ! -x "$VENV/bin/scons" ]]; then
		log "creating python venv + SCons"
		python3 -m venv "$VENV"
		"$VENV/bin/pip" install -q --upgrade pip scons
	fi

	if [[ ! -d "$GODOT_SRC/.git" ]]; then
		log "cloning godot $GODOT_TAG"
		git clone --depth 1 --branch "$GODOT_TAG" https://github.com/godotengine/godot.git "$GODOT_SRC"
	else
		local have
		have="$(git -C "$GODOT_SRC" describe --tags --exact-match 2>/dev/null || true)"
		[[ "$have" == "$GODOT_TAG" ]] || warn "build/godot is at '$have', editor is $GODOT_VER - templates must match!"
	fi

	if [[ ! -f "$SECRETS/encryption.key" ]]; then
		log "generating new 256-bit PCK encryption key"
		if command -v openssl >/dev/null; then
			openssl rand -hex 32 > "$SECRETS/encryption.key"
		else
			python3 -c 'import secrets;print(secrets.token_hex(32))' > "$SECRETS/encryption.key"
		fi
		chmod 600 "$SECRETS/encryption.key"
		warn "BACK UP secrets/encryption.key - losing it means rebuilding all templates"
	fi
	sync_credentials

	[[ -f "$ROOT/.env" ]] || { cp "$ROOT/.env.example" "$ROOT/.env"; log "created .env from .env.example"; }
	"$ROOT/tools/release/install_hooks.sh"
}

setup_windows() {
	local dir="$BUILD/llvm-mingw"
	if [[ -x "$dir/bin/x86_64-w64-mingw32-clang" ]]; then
		log "llvm-mingw already installed"; return
	fi
	need_cmd tar tar
	local url
	url="$(curl -fsSL https://api.github.com/repos/mstorsjo/llvm-mingw/releases/latest \
		| grep -o 'https://[^"]*llvm-mingw-[0-9]*-ucrt-ubuntu-[0-9.]*-x86_64.tar.xz' | head -n1)"
	[[ -n "$url" ]] || die "could not resolve llvm-mingw download URL"
	fetch "$url" "$BUILD/llvm-mingw.tar.xz"
	rm -rf "$dir" && mkdir -p "$dir"
	tar -xJf "$BUILD/llvm-mingw.tar.xz" -C "$dir" --strip-components=1
	rm -f "$BUILD/llvm-mingw.tar.xz"
	log "llvm-mingw installed to $dir"
}

setup_web() {
	local dir="$BUILD/emsdk"
	local ver
	ver="$(grep -m1 'EM_VERSION:' "$GODOT_SRC/.github/workflows/web_builds.yml" | awk '{print $2}')"
	[[ -n "$ver" ]] || ver="latest"
	if [[ -d "$dir" ]] && "$dir/emsdk" list 2>/dev/null | grep -q "INSTALLED.*$ver\|$ver.*INSTALLED"; then
		log "emsdk $ver already installed"; return
	fi
	[[ -d "$dir/.git" ]] || git clone --depth 1 https://github.com/emscripten-core/emsdk.git "$dir"
	log "installing emscripten $ver (Godot CI pin)"
	"$dir/emsdk" install "$ver"
	"$dir/emsdk" activate "$ver"
}

setup_android() {
	local jdk="$BUILD/jdk" sdk="$BUILD/android-sdk"
	need_cmd python3 python3
	if [[ ! -x "$jdk/bin/java" ]]; then
		fetch "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse" "$BUILD/jdk.tar.gz"
		rm -rf "$jdk" && mkdir -p "$jdk"
		tar -xzf "$BUILD/jdk.tar.gz" -C "$jdk" --strip-components=1
		rm -f "$BUILD/jdk.tar.gz"
	fi
	export JAVA_HOME="$jdk" PATH="$jdk/bin:$PATH"

	local ndk build_tools platform
	ndk="$(grep -oP "ndkVersion\s*:\s*'\K[0-9.]+" "$GODOT_SRC/platform/android/java/app/config.gradle")"
	build_tools="$(grep -oP "buildTools\s*:\s*'\K[0-9.]+" "$GODOT_SRC/platform/android/java/app/config.gradle")"
	platform="$(grep -oP "compileSdk\s*:\s*\K[0-9]+" "$GODOT_SRC/platform/android/java/app/config.gradle")"

	if [[ ! -x "$sdk/cmdline-tools/latest/bin/sdkmanager" ]]; then
		fetch "https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip" "$BUILD/cmdline-tools.zip"
		rm -rf "$sdk/cmdline-tools" && mkdir -p "$sdk/cmdline-tools"
		python3 -c "import zipfile,sys;zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$BUILD/cmdline-tools.zip" "$sdk/cmdline-tools"
		mv "$sdk/cmdline-tools/cmdline-tools" "$sdk/cmdline-tools/latest"
		chmod +x "$sdk/cmdline-tools/latest/bin/"*
		rm -f "$BUILD/cmdline-tools.zip"
	fi
	local sdkmanager="$sdk/cmdline-tools/latest/bin/sdkmanager"
	log "accepting Android SDK licenses (Google's terms apply)"
	yes | "$sdkmanager" --sdk_root="$sdk" --licenses >/dev/null || true
	log "installing platform-tools, build-tools;$build_tools, platforms;android-$platform, ndk;$ndk"
	"$sdkmanager" --sdk_root="$sdk" "platform-tools" "build-tools;$build_tools" "platforms;android-$platform" "ndk;$ndk"

	# Godot's Android build refuses to link without the Swappy frame-pacing libs.
	if [[ ! -d "$GODOT_SRC/thirdparty/swappy-frame-pacing/arm64-v8a" ]]; then
		log "installing Swappy frame pacing libs into build/godot/thirdparty"
		(cd "$GODOT_SRC" && "$VENV/bin/python" misc/scripts/install_swappy_android.py)
	fi

	# Release signing keystore (password stored next to it, both git-ignored).
	local alias="${ANDROID_KEY_ALIAS:-whackareporter}"
	if [[ ! -f "$SECRETS/android_release.keystore" ]]; then
		log "generating Android release keystore"
		local pw
		pw="$(python3 -c 'import secrets;print(secrets.token_urlsafe(24))')"
		printf '%s' "$pw" > "$SECRETS/android_release.keystore.pass"
		chmod 600 "$SECRETS/android_release.keystore.pass"
		"$jdk/bin/keytool" -genkeypair -v -keystore "$SECRETS/android_release.keystore" \
			-alias "$alias" -keyalg RSA -keysize 4096 -validity 10000 \
			-storepass "$pw" -keypass "$pw" -dname "CN=$APP_NAME, O=YemotaY" >/dev/null 2>&1
		chmod 600 "$SECRETS/android_release.keystore"
		warn "BACK UP secrets/android_release.keystore(.pass) - Play Store updates require the same key"
	fi
	if [[ ! -f "$SECRETS/android_debug.keystore" ]]; then
		"$jdk/bin/keytool" -genkeypair -v -keystore "$SECRETS/android_debug.keystore" \
			-alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
			-storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
	fi
	log "Android toolchain ready"
}

case "${1:-base}" in
	base)    setup_base ;;
	windows) setup_base; setup_windows ;;
	web)     setup_base; setup_web ;;
	android) setup_base; setup_android ;;
	linux)   setup_base ;;
	ios)     setup_base; [[ "$(uname)" == Darwin ]] || warn "iOS templates can only be compiled on macOS with Xcode" ;;
	all)     setup_base; setup_windows; setup_web; setup_android ;;
	*) die "usage: setup.sh [base|linux|windows|web|android|ios|all]" ;;
esac
