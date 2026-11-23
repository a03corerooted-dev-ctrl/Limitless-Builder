#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-$ROOT/out}"
IMAGE=""
for f in "$OUT_DIR/arch/arm64/boot/Image.gz-dtb" "$OUT_DIR/arch/arm64/boot/Image.gz" "$OUT_DIR/arch/arm64/boot/Image"; do
  if [[ -s "$f" ]]; then IMAGE="$f"; break; fi
done
[[ -n "$IMAGE" ]] || { echo "No non-empty ARM64 kernel image found." >&2; exit 1; }
file "$IMAGE"
printf '%s\n' "$IMAGE" > "$ROOT/validated-image.txt"
