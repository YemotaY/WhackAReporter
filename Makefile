# Whack-A-Reporter release pipeline.
#
#   make setup            venv+SCons, Godot source, key, hooks   (once)
#   make setup-all        + Windows / Web / Android toolchains    (once)
#   make templates        compile hardened export templates      (once per key/engine)
#   make linux windows web android ios     export one platform
#   make itch             web export + butler push to itch.io
#   make release          everything exportable on this machine + verify
#   make test             source smoke test + obfuscated-build smoke test
#   make check-secrets    scan the whole repo for leaked secrets
#
# Version: VERSION=1.2.0 make release   (or set in .env)

SHELL := /usr/bin/env bash
R := tools/release
export VERSION

.PHONY: help setup setup-all setup-windows setup-web setup-android sync-creds hooks \
        templates templates-linux templates-windows templates-web templates-android templates-ios \
        linux windows web android ios macos itch release \
        test test-source test-export export-test verify check-secrets clean-exports

help:
	@sed -n '2,13p' $(MAKEFILE_LIST) | sed 's/^# \{0,1\}//'

# --- setup -------------------------------------------------------------------
setup:          ; $(R)/setup.sh base
setup-all:      ; $(R)/setup.sh all
setup-windows:  ; $(R)/setup.sh windows
setup-web:      ; $(R)/setup.sh web
setup-android:  ; $(R)/setup.sh android
sync-creds:     ; source $(R)/common.sh && sync_credentials
hooks:          ; $(R)/install_hooks.sh

# --- hardened export templates ----------------------------------------------
templates:         templates-linux templates-windows templates-web templates-android
templates-linux:   ; $(R)/build_templates.sh linux && $(R)/build_templates.sh linux-test
templates-windows: ; $(R)/build_templates.sh windows
templates-web:     ; $(R)/build_templates.sh web
templates-android: ; $(R)/build_templates.sh android
templates-ios:     ; $(R)/build_templates.sh ios

# --- exports -----------------------------------------------------------------
linux:   check-secrets ; $(R)/export.sh linux   && $(R)/verify_export.sh linux
windows: check-secrets ; $(R)/export.sh windows && $(R)/verify_export.sh windows
web:     check-secrets ; $(R)/export.sh web     && $(R)/verify_export.sh web
android: check-secrets ; $(R)/export.sh android && $(R)/verify_export.sh android
ios:     check-secrets ; $(R)/export.sh ios
macos:   check-secrets ; $(R)/export.sh macos

all: 	 check-secrets ; $(R)/export.sh linux   && $(R)/verify_export.sh linux ; $(R)/export.sh windows && $(R)/verify_export.sh windows; $(R)/export.sh web     && $(R)/verify_export.sh web; $(R)/export.sh android && $(R)/verify_export.sh android

itch: web ; $(R)/itch_push.sh web

# Everything that can be produced on a Linux box. iOS/macOS need a Mac.
release: linux windows web android verify
	@echo; echo "release v$${VERSION:-1.0.0} ready in export/"

# --- tests -------------------------------------------------------------------
test: test-source test-export

test-source:
	godot --headless --path . -s tests/smoke_test.gd

export-test: ; $(R)/export.sh test
test-export: export-test ; $(R)/verify_export.sh test

verify: ; $(R)/verify_export.sh all

# --- hygiene -----------------------------------------------------------------
check-secrets: ; $(R)/check_secrets.sh --all

clean-exports: ; rm -rf export/ build/test_export
