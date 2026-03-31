#!/bin/sh
set -e

cd "$HOME"/rustdesk || exit 1
# shellcheck source=/dev/null
. "$HOME"/.cargo/env

argv=$*
flutter_mode=0

while test $# -gt 0; do
  case "$1" in
  --release)
    mkdir -p target/release
    test -f target/release/libsciter-gtk.so || cp "$HOME"/libsciter-gtk.so target/release/
    release=1
    shift
    ;;
  --target)
    shift
    if test $# -gt 0; then
      rustup target add "$1"
      shift
    fi
    ;;
  --features)
    shift
    if test $# -gt 0; then
      case "$1" in
        *flutter*)
          flutter_mode=1
          ;;
      esac
      shift
    fi
    ;;
  *)
    shift
    ;;
  esac
done

if [ -z "$release" ]; then
  mkdir -p target/debug
  test -f target/debug/libsciter-gtk.so || cp "$HOME"/libsciter-gtk.so target/debug/
fi

if [ "$flutter_mode" = "1" ]; then
  git config --global --add safe.directory "$HOME/rustdesk"
  git config --global --add safe.directory /opt/flutter
  flutter --disable-analytics 2>/dev/null || true
  dart --disable-analytics 2>/dev/null || true

  # Get Flutter dependencies
  cd flutter && flutter pub get && cd ..

  # Generate flutter_rust_bridge bindings
  "$HOME"/.cargo/bin/flutter_rust_bridge_codegen \
    --rust-input ./src/flutter_ffi.rs \
    --dart-output ./flutter/lib/generated_bridge.dart

  # Workaround ffigen
  sed -i "s/ffi.NativeFunction<ffi.Bool Function(DartPort/ffi.NativeFunction<ffi.Uint8 Function(DartPort/g" flutter/lib/generated_bridge.dart

  # Build Rust lib
  set -f
  #shellcheck disable=2086
  VCPKG_ROOT=/vcpkg cargo build $argv

  # Build Flutter app
  cd flutter
  flutter build linux --release
else
  set -f
  #shellcheck disable=2086
  VCPKG_ROOT=/vcpkg cargo build $argv
fi
