#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/config/a03.env"
OUT_DIR="${OUT_DIR:-$ROOT/out}"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"

IMAGE="$OUT_DIR/arch/arm64/boot/Image"
IMAGE_GZ="$OUT_DIR/arch/arm64/boot/Image.gz-dtb"
BOOT_IMAGE="$OUT_DIR/boot.img"
DTB="$OUT_DIR/arch/arm64/boot/dts/sprd/ums9230.dtb"
DTBO_4H10="$OUT_DIR/arch/arm64/boot/dts/sprd/ums9230-4h10-overlay.dtbo"
MODULE_SYMVERS="$OUT_DIR/Module.symvers"
SYSTEM_MAP="$OUT_DIR/System.map"

[[ -s "$IMAGE" ]] || { echo "Missing non-empty ARM64 Image." >&2; exit 1; }
[[ -s "$IMAGE_GZ" ]] || { echo "Missing compressed Image.gz-dtb output." >&2; exit 1; }
[[ -s "$BOOT_IMAGE" ]] || { echo "Missing repacked boot.img." >&2; exit 1; }
[[ -s "$DTB" ]] || { echo "Missing qogirl6 UMS9230 DTB." >&2; exit 1; }
[[ -s "$DTBO_4H10" ]] || { echo "Missing UMS9230 4H10 DTBO." >&2; exit 1; }
[[ -s "$MODULE_SYMVERS" ]] || { echo "Missing Module.symvers." >&2; exit 1; }
[[ -s "$SYSTEM_MAP" ]] || { echo "Missing System.map." >&2; exit 1; }
[[ -s "$OUT_DIR/boot-packaging-info.txt" ]] || { echo "Missing boot packaging verification report." >&2; exit 1; }
[[ -s "$ROOT/kernelrelease.txt" ]] || { echo "Missing exact kernel release record." >&2; exit 1; }

ACTUAL_KERNEL_RELEASE="$(cat "$ROOT/kernelrelease.txt")"
[[ "$ACTUAL_KERNEL_RELEASE" == "$EXPECTED_KERNEL_RELEASE" ]] || {
  echo "Kernel release mismatch: expected '$EXPECTED_KERNEL_RELEASE', got '$ACTUAL_KERNEL_RELEASE'." >&2
  exit 1
}

gzip -t "$IMAGE_GZ"
gzip -dc "$IMAGE_GZ" | cmp -s - "$IMAGE" || {
  echo "Compressed image payload does not match the raw ARM64 Image." >&2
  exit 1
}

MODULE_LAYOUT_CRC="$(awk '$2 == "module_layout" { print $1; exit }' "$MODULE_SYMVERS")"
[[ "$MODULE_LAYOUT_CRC" == "$STOCK_MODULE_LAYOUT_CRC" ]] || {
  echo "module_layout CRC mismatch: expected '$STOCK_MODULE_LAYOUT_CRC', got '${MODULE_LAYOUT_CRC:-missing}'." >&2
  exit 1
}

file "$IMAGE" "$IMAGE_GZ" "$BOOT_IMAGE" "$DTB" "$DTBO_4H10"
printf '%s\n' "$IMAGE" > "$ROOT/validated-image.txt"
printf '%s\n' "$IMAGE_GZ" > "$ROOT/validated-gzip-image.txt"
printf '%s\n' "$BOOT_IMAGE" > "$ROOT/validated-boot-image.txt"
echo "Validated kernel release: $ACTUAL_KERNEL_RELEASE"
echo "Validated module_layout CRC: $MODULE_LAYOUT_CRC"
