#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
download_toolchain() {
  local url="$1" dest="$2" label="$3"
  [[ -n "$url" ]] || { echo "ERROR: configure $label archive URL or provide its directory." >&2; return 1; }
  mkdir -p "$dest"
  local archive
  archive="$(mktemp)"
  curl --fail --location --retry 3 "$url" --output "$archive"
  tar -xf "$archive" -C "$dest"
  rm -f "$archive"
}
GCC_DIR="${LIMITLESS_GCC_DIR:-$ROOT/.toolchains/gcc}"
CLANG_DIR="${LIMITLESS_CLANG_DIR:-$ROOT/.toolchains/clang}"
if [[ ! -x "$GCC_DIR/bin/aarch64-linux-android-gcc" ]]; then
  download_toolchain "${LIMITLESS_GCC_URL:-}" "$GCC_DIR" "AArch64 GCC 4.9"
fi
if [[ ! -x "$CLANG_DIR/bin/clang" ]]; then
  download_toolchain "${LIMITLESS_CLANG_URL:-}" "$CLANG_DIR" "Clang r383902"
fi
"$GCC_DIR/bin/aarch64-linux-android-gcc" --version | head -n 1
"$CLANG_DIR/bin/clang" --version | head -n 1
