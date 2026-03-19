#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/ThirdParty/src/ghostty"
OUT_DIR="$ROOT/ThirdParty/lib"

mkdir -p "$ROOT/ThirdParty/src" "$OUT_DIR"

if [[ ! -d "$SRC" ]]; then
  git clone https://github.com/ghostty-org/ghostty.git "$SRC"
else
  git -C "$SRC" pull --rebase
fi

if ! command -v zig >/dev/null 2>&1; then
  echo "Zig is required to build Ghostty. Please install Zig 0.15.2 and ensure it is on PATH."
  exit 1
fi

ZIG_VERSION="$(zig version)"
if [[ "$ZIG_VERSION" != 0.15.2* ]]; then
  echo "Ghostty requires Zig 0.15.2 (found $ZIG_VERSION)."
  exit 1
fi

(
  cd "$SRC"
  zig build -Dapp-runtime=none -Demit-xcframework=true -Demit-macos-app=false -Dxcframework-target=native
)

rm -rf "$OUT_DIR/GhosttyKit.xcframework"
cp -R "$SRC/macos/GhosttyKit.xcframework" "$OUT_DIR/GhosttyKit.xcframework"

echo "GhosttyKit.xcframework installed to $OUT_DIR"
