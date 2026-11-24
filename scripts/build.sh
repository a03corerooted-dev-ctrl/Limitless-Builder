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
export LOCALVERSION
export CROSS_COMPILE="$GCC_DIR/bin/$CROSS_COMPILE"
export PATH="$CLANG_DIR/bin:$GCC_DIR/bin:$PATH"
export KBUILD_BUILD_USER=Limitless
export KBUILD_BUILD_HOST=limitless-builder
export BSP_BUILD_FAMILY=qogirl6
export BSP_BUILD_ANDROID_OS=y
export DTC_OVERLAY_TEST_EXT="$SOURCE_DIR/tools/mkdtimg/ufdt_apply_overlay"
export DTC_OVERLAY_VTS_EXT="$SOURCE_DIR/tools/mkdtimg/ufdt_verify_overlay_host"

# The checked-in Android host verifier has a legacy DT_NEEDED entry for
# "libc++.so" (the development linker name), rather than the runtime SONAME
# "libc++.so.1". Provide a private compatibility alias without modifying
# system library paths or the tracked binary.
LIBCXX_RUNTIME="$(ldconfig -p | awk '$1 == "libc++.so.1" && $2 ~ /x86-64/ {print $NF; exit}')"
[[ -n "$LIBCXX_RUNTIME" && -s "$LIBCXX_RUNTIME" ]] || {
  echo "ERROR: libc++.so.1 runtime library is missing; install libc++1-14." >&2
  ldconfig -p | grep -F 'libc++.so' >&2 || true
  exit 1
}
HOST_COMPAT_LIB_DIR="$ROOT/.host-libs"
mkdir -p "$HOST_COMPAT_LIB_DIR"
ln -sfn "$LIBCXX_RUNTIME" "$HOST_COMPAT_LIB_DIR/libc++.so"
export LD_LIBRARY_PATH="$HOST_COMPAT_LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
echo "libcxx_runtime=$LIBCXX_RUNTIME"
echo "libcxx_compat_alias=$HOST_COMPAT_LIB_DIR/libc++.so"

[[ -x "$DTC_OVERLAY_TEST_EXT" ]] || {
  echo "Missing executable DT overlay test helper: $DTC_OVERLAY_TEST_EXT" >&2
  exit 1
}
[[ -x "$DTC_OVERLAY_VTS_EXT" ]] || {
  echo "Missing executable DT overlay verification helper: $DTC_OVERLAY_VTS_EXT" >&2
  exit 1
}

# Validate the host-side DT overlay verifier before the kernel build. This
# catches broken runtime dependencies (including truncated libc++ libraries)
# at their source instead of allowing a later, misleading DTBO/Image failure.
{
  echo "helper=$DTC_OVERLAY_VTS_EXT"
  file "$DTC_OVERLAY_VTS_EXT"
  if file -b "$DTC_OVERLAY_VTS_EXT" | grep -q 'ELF'; then
    ldd "$DTC_OVERLAY_VTS_EXT"
  else
    echo "Verifier is not an ELF executable; dynamic dependency check skipped."
  fi
} > "$ROOT/ufdt-host-deps.log" 2>&1 || {
  cat "$ROOT/ufdt-host-deps.log" >&2
  exit 1
}

if grep -Eqi 'not found|file too short|wrong ELF class|error while loading shared libraries' "$ROOT/ufdt-host-deps.log"; then
  cat "$ROOT/ufdt-host-deps.log" >&2
  echo "ERROR: DT overlay verifier has an invalid or unresolved host dependency." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
make -C "$SOURCE_DIR" O="$OUT_DIR" BSP_BUILD_DT_OVERLAY=y "$DEFCONFIG"

CONFIG_FILE="$OUT_DIR/.config"
grep -qx 'CONFIG_LOCALVERSION=""' "$CONFIG_FILE" || {
  echo "Stock CONFIG_LOCALVERSION must remain empty; found a non-stock value." >&2
  exit 1
}

# Keep the first boot build aligned with the extracted CYG1 stock .config.
for option in CONFIG_BPF CONFIG_BPF_SYSCALL CONFIG_BPF_JIT CONFIG_BPF_JIT_ALWAYS_ON CONFIG_CGROUP_BPF CONFIG_NET_CLS_BPF CONFIG_NET_CLS_ACT CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL CONFIG_CPU_FREQ_GOV_SCHEDUTIL CONFIG_MODULES CONFIG_MODULE_UNLOAD CONFIG_MODVERSIONS; do
  grep -qx "$option=y" "$CONFIG_FILE" || {
    echo "Stock baseline config option is not enabled: $option" >&2
    exit 1
  }
done

# These optional HyperBPF features are deliberately deferred until the stock
# kernel has booted and the vendor-module ABI has been checked.
for option in CONFIG_NET_ACT_BPF CONFIG_BPF_STREAM_PARSER CONFIG_STREAM_PARSER; do
  grep -qx "# $option is not set" "$CONFIG_FILE" || {
    echo "Non-stock optional BPF feature is unexpectedly enabled: $option" >&2
    exit 1
  }
done

KERNEL_RELEASE="$(make -s -C "$SOURCE_DIR" O="$OUT_DIR" BSP_BUILD_DT_OVERLAY=y kernelrelease)"
[[ "$KERNEL_RELEASE" == "$EXPECTED_KERNEL_RELEASE" ]] || {
  echo "Kernel release mismatch: expected '$EXPECTED_KERNEL_RELEASE', got '$KERNEL_RELEASE'." >&2
  exit 1
}
printf '%s\\n' "$KERNEL_RELEASE" > "$ROOT/kernelrelease.txt"
echo "kernel_release=$KERNEL_RELEASE"

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
[[ -s "$OUT_DIR/Module.symvers" ]] || {
  echo "Kernel build completed without Module.symvers." >&2
  exit 1
}
[[ -s "$OUT_DIR/System.map" ]] || {
  echo "Kernel build completed without System.map." >&2
  exit 1
}

MODULE_LAYOUT_CRC="$(awk '$2 == "module_layout" { print $1; exit }' "$OUT_DIR/Module.symvers")"
[[ "$MODULE_LAYOUT_CRC" == "$STOCK_MODULE_LAYOUT_CRC" ]] || {
  echo "module_layout CRC mismatch: expected '$STOCK_MODULE_LAYOUT_CRC', got '${MODULE_LAYOUT_CRC:-missing}'." >&2
  exit 1
}
echo "module_layout_crc=$MODULE_LAYOUT_CRC"

git -C "$SOURCE_DIR" rev-parse HEAD > "$ROOT/source-commit.txt"
printf '%s\n' "$SOURCE_REF" > "$ROOT/source-ref.txt"

bash "$ROOT/scripts/package-boot.sh"
