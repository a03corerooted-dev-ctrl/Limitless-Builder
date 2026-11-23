#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-$ROOT/out}"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
IMAGE="$OUT_DIR/arch/arm64/boot/Image"
IMAGE_GZ_DTB="$OUT_DIR/arch/arm64/boot/Image.gz-dtb"
BOOT_IMAGE="$OUT_DIR/boot.img"

[[ -s "$IMAGE" ]] || { echo "Missing non-empty ARM64 Image." >&2; exit 1; }
[[ -s "$IMAGE_GZ_DTB" ]] || { echo "Missing non-empty Image.gz-dtb." >&2; exit 1; }
[[ -s "$BOOT_IMAGE" ]] || { echo "Missing non-empty repacked boot.img." >&2; exit 1; }
[[ -s "$OUT_DIR/boot-packaging-info.txt" ]] || {
  echo "Missing boot packaging provenance/verification report." >&2
  exit 1
}

file "$IMAGE" "$IMAGE_GZ_DTB" "$BOOT_IMAGE"
printf '%s\n' "$IMAGE_GZ_DTB" > "$ROOT/validated-image.txt"
printf '%s\n' "$BOOT_IMAGE" > "$ROOT/validated-boot-image.txt"
