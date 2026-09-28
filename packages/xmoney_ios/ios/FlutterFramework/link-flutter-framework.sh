#!/bin/sh
# Point Flutter.xcframework at the local Flutter engine so the plugin package can import Flutter.
set -eu

dest_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
dest="$dest_dir/Flutter.xcframework"

if [ -e "$dest" ]; then
  exit 0
fi

if [ -z "${FLUTTER_ROOT:-}" ]; then
  flutter_bin="$(command -v flutter || true)"
  if [ -n "$flutter_bin" ]; then
    while [ -L "$flutter_bin" ]; do
      link="$(readlink "$flutter_bin")"
      case "$link" in
        /*) flutter_bin="$link" ;;
        *) flutter_bin="$(dirname "$flutter_bin")/$link" ;;
      esac
    done
    FLUTTER_ROOT="$(CDPATH= cd -- "$(dirname "$flutter_bin")/.." && pwd)"
  fi
fi

if [ -z "${FLUTTER_ROOT:-}" ]; then
  echo "FLUTTER_ROOT is not set and flutter is not on PATH." >&2
  exit 1
fi

src="$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.xcframework"
if [ ! -d "$src" ]; then
  echo "Flutter.xcframework not found at $src. Run: flutter precache --ios" >&2
  exit 1
fi

ln -sfn "$src" "$dest"
