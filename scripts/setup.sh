#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

download_toolchain() {
  local url="$1" dest="$2" label="$3"
  [[ -n "$url" ]] || {
    echo "ERROR: configure $label archive URL or provide its directory." >&2
    return 1
  }
  mkdir -p "$dest"
  local archive
  archive="$(mktemp)"
  curl --fail --location --retry 3 "$url" --output "$archive"
  tar -xf "$archive" -C "$dest"
  rm -f "$archive"
}

normalize_toolchain_bin() {
  local root="$1" executable="$2" label="$3"
  [[ -x "$root/bin/$executable" ]] && return 0

  local found
  found="$(find "$root" -type f -name "$executable" -perm -u+x -print -quit)"
  [[ -n "$found" ]] || {
    echo "ERROR: could not locate $label executable '$executable' under $root" >&2
    return 1
  }

  local bin_dir="$(
    cd "$(dirname "$found")"
    pwd
  )"
  if [[ -e "$root/bin" || -L "$root/bin" ]]; then
    mv "$root/bin" "$root/bin.unresolved.$(date +%s)"
  fi
  ln -s "$bin_dir" "$root/bin"
  [[ -x "$root/bin/$executable" ]] || {
    echo "ERROR: failed to normalize $label toolchain path." >&2
    return 1
  }
}

GCC_DIR="${LIMITLESS_GCC_DIR:-$ROOT/.toolchains/gcc}"
CLANG_DIR="${LIMITLESS_CLANG_DIR:-$ROOT/.toolchains/clang}"

mkdir -p "$GCC_DIR" "$CLANG_DIR"
if [[ ! -x "$GCC_DIR/bin/aarch64-linux-android-gcc" ]]; then
  if ! find "$GCC_DIR" -type f -name aarch64-linux-android-gcc -perm -u+x -print -quit | grep -q .; then
    download_toolchain "${LIMITLESS_GCC_URL:-}" "$GCC_DIR" "AArch64 GCC 4.9"
  fi
fi
if [[ ! -x "$CLANG_DIR/bin/clang" ]]; then
  if ! find "$CLANG_DIR" -type f -name clang -perm -u+x -print -quit | grep -q .; then
    download_toolchain "${LIMITLESS_CLANG_URL:-}" "$CLANG_DIR" "Clang r383902"
  fi
fi

normalize_toolchain_bin "$GCC_DIR" aarch64-linux-android-gcc "AArch64 GCC 4.9"
normalize_toolchain_bin "$CLANG_DIR" clang "Clang r383902"
[[ -x "$CLANG_DIR/bin/ld.lld" ]] || {
  echo "ERROR: Clang toolchain is missing ld.lld in its bin directory." >&2
  exit 1
}

"$GCC_DIR/bin/aarch64-linux-android-gcc" --version | head -n 1 | tee "$ROOT/toolchain-info.txt"
"$CLANG_DIR/bin/clang" --version | head -n 1 | tee -a "$ROOT/toolchain-info.txt"
