#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/config/a03.env"

SOURCE_DIR="${LIMITLESS_SOURCE_DIR:-$ROOT/source}"
SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"
OUT_DIR="${OUT_DIR:-$ROOT/out}"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
KERNEL_IMAGE="$OUT_DIR/arch/arm64/boot/Image"
STOCK_ARCHIVE="${LIMITLESS_STOCK_BOOT_ARCHIVE:-$SOURCE_DIR/Publish/a03-A035FXXS7CXF3.tar.xz}"
MAGISKBOOT="${LIMITLESS_MAGISKBOOT:-$SOURCE_DIR/Publish/magiskboot}"
STOCK_MEMBER="${LIMITLESS_STOCK_BOOT_MEMBER:-stock-boot.img}"
[[ "$STOCK_ARCHIVE" = /* ]] || STOCK_ARCHIVE="$ROOT/$STOCK_ARCHIVE"
[[ "$MAGISKBOOT" = /* ]] || MAGISKBOOT="$ROOT/$MAGISKBOOT"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/limitless-boot.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

[[ -s "$KERNEL_IMAGE" ]] || {
  echo "Missing ARM64 Image: $KERNEL_IMAGE" >&2
  exit 1
}
[[ -s "$STOCK_ARCHIVE" ]] || {
  echo "Missing source stock-boot archive: $STOCK_ARCHIVE" >&2
  exit 1
}
[[ -x "$MAGISKBOOT" ]] || {
  echo "Missing executable magiskboot: $MAGISKBOOT" >&2
  exit 1
}

tar -tf "$STOCK_ARCHIVE" | grep -Fxq "$STOCK_MEMBER" || {
  echo "Archive does not contain expected member: $STOCK_MEMBER" >&2
  exit 1
}

tar -xOf "$STOCK_ARCHIVE" "$STOCK_MEMBER" > "$WORK_DIR/stock-boot.img"
[[ -s "$WORK_DIR/stock-boot.img" ]] || {
  echo "Extracted stock boot image is empty." >&2
  exit 1
}

cp "$MAGISKBOOT" "$WORK_DIR/magiskboot"
chmod 0755 "$WORK_DIR/magiskboot"
cp "$KERNEL_IMAGE" "$WORK_DIR/kernel"

(
  cd "$WORK_DIR"
  ./magiskboot unpack stock-boot.img
  [[ -s ramdisk.cpio ]] || {
    echo "magiskboot did not extract a ramdisk; refusing to repack." >&2
    exit 1
  }
  cp "$KERNEL_IMAGE" kernel
  ./magiskboot repack stock-boot.img "$OUT_DIR/boot.img"
)

[[ -s "$OUT_DIR/boot.img" ]] || {
  echo "magiskboot did not create a non-empty boot.img." >&2
  exit 1
}

VERIFY_DIR="$WORK_DIR/verify"
mkdir -p "$VERIFY_DIR"
cp "$OUT_DIR/boot.img" "$VERIFY_DIR/boot.img"
cp "$MAGISKBOOT" "$VERIFY_DIR/magiskboot"
chmod 0755 "$VERIFY_DIR/magiskboot"
(
  cd "$VERIFY_DIR"
  ./magiskboot unpack boot.img
  cmp -s kernel "$KERNEL_IMAGE" || {
    echo "Repacked boot kernel does not match the built Image." >&2
    exit 1
  }
)

{
  printf 'stock_archive=%s\n' "${STOCK_ARCHIVE#"$SOURCE_DIR"/}"
  printf 'stock_member=%s\n' "$STOCK_MEMBER"
  printf 'stock_boot_sha256='
  sha256sum "$WORK_DIR/stock-boot.img" | awk '{print $1}'
  printf 'kernel_image_sha256='
  sha256sum "$KERNEL_IMAGE" | awk '{print $1}'
  printf 'repacked_boot_sha256='
  sha256sum "$OUT_DIR/boot.img" | awk '{print $1}'
  printf 'stock_firmware_reference=A035FXXS7CXF3 (from source tree archive)\n'
  printf 'verification=magiskboot unpack + extracted-kernel byte comparison passed\n'
} > "$OUT_DIR/boot-packaging-info.txt"

echo "Boot image packaged and structurally verified: $OUT_DIR/boot.img"
