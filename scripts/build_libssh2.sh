#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/ThirdParty/src/libssh2"
BUILD="$ROOT/ThirdParty/build/libssh2_macos15"
INSTALL="$ROOT/ThirdParty"

mkdir -p "$ROOT/ThirdParty/src" "$BUILD" "$INSTALL"

if [[ ! -d "$SRC" ]]; then
  git clone https://github.com/libssh2/libssh2.git "$SRC"
else
  git -C "$SRC" pull --rebase
fi

cmake -S "$SRC" -B "$BUILD" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$INSTALL" \
  -DCRYPTO_BACKEND=OpenSSL \
  -DOPENSSL_ROOT_DIR="$INSTALL" \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_STATIC_LIBS=ON

cmake --build "$BUILD" --config Release -j"$(sysctl -n hw.ncpu)"
cmake --install "$BUILD"

echo "libssh2 installed to $INSTALL"
