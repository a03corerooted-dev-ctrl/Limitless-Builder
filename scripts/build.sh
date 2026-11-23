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
command -v nproc >/dev/null

if [[ ! -d "$SOURCE_DIR/.git" ]]; then
  git clone --filter=blob:none "$SOURCE_REPOSITORY" "$SOURCE_DIR"
fi
SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"

git -C "$SOURCE_DIR" fetch --prune origin "$SOURCE_REF"
git -C "$SOURCE_DIR" checkout --detach FETCH_HEAD

[[ -x "$GCC_DIR/bin/aarch64-linux-android-gcc" ]] || {
  echo "AArch64 GCC 4.9 not found: $GCC_DIR" >&2
  exit 1
}
[[ -x "$CLANG_DIR/bin/clang" && -x "$CLANG_DIR/bin/ld.lld" ]] || {
  echo "Clang r383902 / LLD not found: $CLANG_DIR" >&2
  exit 1
}

export ARCH SUBARCH="$ARCH"
export CROSS_COMPILE="$GCC_DIR/bin/$CROSS_COMPILE"
export PATH="$CLANG_DIR/bin:$GCC_DIR/bin:$PATH"
export KBUILD_BUILD_USER=Limitless
export KBUILD_BUILD_HOST=limitless-builder
export BSP_BUILD_FAMILY=qogirl6
export BSP_BUILD_ANDROID_OS=y
export DTC_OVERLAY_TEST_EXT="$SOURCE_DIR/tools/mkdtimg/ufdt_apply_overlay"
export DTC_OVERLAY_VTS_EXT="$SOURCE_DIR/tools/mkdtimg/ufdt_verify_overlay_host"

[[ -x "$DTC_OVERLAY_TEST_EXT" ]] || {
  echo "Missing executable DT overlay test helper: $DTC_OVERLAY_TEST_EXT" >&2
  exit 1
}
[[ -x "$DTC_OVERLAY_VTS_EXT" ]] || {
  echo "Missing executable DT overlay verification helper: $DTC_OVERLAY_VTS_EXT" >&2
  exit 1
}

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
make -C "$SOURCE_DIR" O="$OUT_DIR" BSP_BUILD_DT_OVERLAY=y "$DEFCONFIG"
make -C "$SOURCE_DIR" O="$OUT_DIR" -j"$(nproc)" \
  BSP_BUILD_DT_OVERLAY=y \
  CC="$CLANG_DIR/bin/clang" CROSS_COMPILE="$CROSS_COMPILE" \
  CLANG_TRIPLE="$CLANG_TRIPLE" LD="$CLANG_DIR/bin/ld.lld" \
  Image.gz-dtb

[[ -s "$OUT_DIR/arch/arm64/boot/Image" ]] || {
  echo "Kernel build completed without arch/arm64/boot/Image" >&2
  exit 1
}
[[ -s "$OUT_DIR/arch/arm64/boot/Image.gz-dtb" ]] || {
  echo "Kernel build completed without Image.gz-dtb" >&2
  exit 1
}

git -C "$SOURCE_DIR" rev-parse HEAD > "$ROOT/source-commit.txt"
printf '%s\n' "$SOURCE_REF" > "$ROOT/source-ref.txt"

bash "$ROOT/scripts/package-boot.sh"
