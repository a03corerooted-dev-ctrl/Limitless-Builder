#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Immutable toolchain snapshots. Both archives are pinned to Git commits;
# environment variables remain available for trusted local mirrors.
DEFAULT_GCC_URL="https://github.com/SlimRoms/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9/archive/7280ce2399316a5dbd8872e0bfe69435d8719230.tar.gz"
DEFAULT_CLANG_URL="https://github.com/AOSP-10/prebuilts_clang_host_linux-x86_clang-r383902/archive/23ba73b5770985b6bf5f38efceba99019178025c.tar.gz"

download_toolchain() {
  local url="$1" dest="$2" label="$3"
  [[ -n "$url" ]] || {
    echo "ERROR: no download URL configured for $label." >&2
    return 1
  }

  mkdir -p "$dest"
  local archive
  archive="$(mktemp)"
  echo "Downloading pinned $label toolchain..."
  curl --fail --location --retry 3 --retry-all-errors --connect-timeout 30 "$url" --output "$archive"

  tar -tzf "$archive" >/dev/null
  # GitHub source archives contain one wrapper directory. Strip it so the
  # compiler retains its expected relative bin/lib/libexec layout.
  if tar -tzf "$archive" | awk -F/ 'NR == 1 { root = $1 } $1 != root { bad = 1 } END { exit (NR == 0 || bad) }'; then
    tar -xzf "$archive" --strip-components=1 -C "$dest"
  else
    tar -xzf "$archive" -C "$dest"
  fi
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
    download_toolchain "${LIMITLESS_GCC_URL:-$DEFAULT_GCC_URL}" "$GCC_DIR" "AArch64 GCC 4.9"
  fi
fi
if [[ ! -x "$CLANG_DIR/bin/clang" ]]; then
  if ! find "$CLANG_DIR" -type f -name clang -perm -u+x -print -quit | grep -q .; then
    download_toolchain "${LIMITLESS_CLANG_URL:-$DEFAULT_CLANG_URL}" "$CLANG_DIR" "Clang r383902"
  fi
fi

normalize_toolchain_bin "$GCC_DIR" aarch64-linux-android-gcc "AArch64 GCC 4.9"
normalize_toolchain_bin "$CLANG_DIR" clang "Clang r383902"
[[ -x "$CLANG_DIR/bin/ld.lld" ]] || {
  echo "ERROR: Clang toolchain is missing ld.lld in its bin directory." >&2
  exit 1
}

GCC_VERSION="$("$GCC_DIR/bin/aarch64-linux-android-gcc" -dumpversion)"
[[ "$GCC_VERSION" == 4.9* ]] || {
  echo "ERROR: expected AArch64 GCC 4.9, found '$GCC_VERSION'." >&2
  exit 1
}
CLANG_VERSION="$("$CLANG_DIR/bin/clang" --version | head -n 1)"
[[ "$CLANG_VERSION" == *"11.0.1"* ]] || {
  echo "ERROR: expected Clang 11.0.1 / r383902, found '$CLANG_VERSION'." >&2
  exit 1
}

{
  echo "gcc_source=SlimRoms/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9@7280ce2399316a5dbd8872e0bfe69435d8719230"
  echo "clang_source=AOSP-10/prebuilts_clang_host_linux-x86_clang-r383902@23ba73b5770985b6bf5f38efceba99019178025c"
  echo "gcc_version=$GCC_VERSION"
  echo "clang_version=$CLANG_VERSION"
} | tee "$ROOT/toolchain-info.txt"
