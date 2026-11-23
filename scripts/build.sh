#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/config/a03.env"
SOURCE_DIR="${LIMITLESS_SOURCE_DIR:-$ROOT/source}"
SOURCE_REF="${LIMITLESS_SOURCE_REF:-$SOURCE_REF}"
OUT_DIR="${OUT_DIR:-$ROOT/out}"
GCC_DIR="${LIMITLESS_GCC_DIR:-$ROOT/.toolchains/gcc}"
CLANG_DIR="${LIMITLESS_CLANG_DIR:-$ROOT/.toolchains/clang}"
command -v git >/dev/null
command -v make >/dev/null
if [[ ! -d "$SOURCE_DIR/.git" ]]; then git clone --filter=blob:none "$SOURCE_REPOSITORY" "$SOURCE_DIR"; fi
git -C "$SOURCE_DIR" fetch --prune origin "$SOURCE_REF"
git -C "$SOURCE_DIR" checkout --detach FETCH_HEAD
[[ -x "$GCC_DIR/bin/aarch64-linux-android-gcc" ]] || { echo "AArch64 GCC 4.9 not found: $GCC_DIR" >&2; exit 1; }
[[ -x "$CLANG_DIR/bin/clang" && -x "$CLANG_DIR/bin/ld.lld" ]] || { echo "Clang/LLD toolchain not found: $CLANG_DIR" >&2; exit 1; }
export ARCH SUBARCH="$ARCH"
export CROSS_COMPILE="$GCC_DIR/bin/$CROSS_COMPILE"
export PATH="$CLANG_DIR/bin:$GCC_DIR/bin:$PATH"
export KBUILD_BUILD_USER=Limitless KBUILD_BUILD_HOST=limitless-builder
mkdir -p "$OUT_DIR"
make -C "$SOURCE_DIR" O="$OUT_DIR" "$DEFCONFIG"
make -C "$SOURCE_DIR" O="$OUT_DIR" -j"$(nproc)" \
  CC="$CLANG_DIR/bin/clang" CROSS_COMPILE="$CROSS_COMPILE" \
  CLANG_TRIPLE="$CLANG_TRIPLE" LD="$CLANG_DIR/bin/ld.lld" Image.gz-dtb
git -C "$SOURCE_DIR" rev-parse HEAD > "$ROOT/source-commit.txt"
