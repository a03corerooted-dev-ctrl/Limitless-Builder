# Limitless Builder

Independent build and release pipeline for Limitless on Samsung Galaxy A03 (qogirl6 / UMS9230).

## Design

- Kernel source: `a03corerooted-dev-ctrl/limitless_android_kernel_samsung_a03`.
- Builder code is independent; it does not use or modify NonGKI_Kernel_Build-K419.
- GitHub Releases and Actions are the build/publish interface.
- The pipeline produces the raw ARM64 `Image`, a gzip-compressed `Image.gz`, the repacked `boot.img`, and diagnostic ABI/build files.
- The BSP target is named `Image.gz-dtb`, but in this tree it builds a gzip-only kernel payload while compiling DTB/DTBO targets separately. The artifact is therefore published as `Image.gz`, not mislabeled as a kernel with an appended DTB.
- The boot package uses `Publish/a03-A035FXXS7CXF3.tar.xz` and its bundled `magiskboot`. The repack replaces the kernel and verifies that the extracted kernel, ramdisk CPIO and embedded DTB are byte-identical to their stock extracted counterparts.
- The source archive is S7CXF3; the tester device is S9CYG1. During the project audit, the decompressed ramdisk CPIO and embedded DTB were verified byte-identical between those two stock images. The boot header name and Android patch metadata differ (SRPUH31A007 / 2024-07 versus SRPUH31A009 / 2025-08). The output remains an engineering test artifact until a real device boot is confirmed.
- The device's existing CYG1 DTBO partition is left unchanged for the first test. Do not use this A035F package for SM-A035M or SM-A035G without variant-specific assets and validation.

## Entry points

- `push` to the builder's `limitless/dev` branch: automatically builds the latest `limitless/dev` kernel-source commit.
- `workflow_dispatch`: manually builds the latest `limitless/dev` kernel-source commit. Older tags and arbitrary SHAs are intentionally not selectable for the baseline pipeline.
- The exact kernel-source SHA is recorded. The build aborts if the source branch advances while compilation is running.

## Toolchains

The builder downloads pinned snapshots by default:
- AArch64 GCC 4.9 from `SlimRoms/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9` at commit `7280ce2399316a5dbd8872e0bfe69435d8719230`.
- Clang r383902 from `AOSP-10/prebuilts_clang_host_linux-x86_clang-r383902` at commit `23ba73b5770985b6bf5f38efceba99019178025c`.

No Actions variables are required for the default setup. For trusted mirrors, `LIMITLESS_GCC_URL` and `LIMITLESS_CLANG_URL` can override the pinned archive URLs. Optionally set `LIMITLESS_GCC_DIR` / `LIMITLESS_CLANG_DIR` if the runner already provides the matching toolchains. The setup records both pinned source commits in `toolchain-info.txt` and does not silently substitute compiler versions.

## Local build

```sh
export LIMITLESS_SOURCE_REF=limitless/dev
bash ./scripts/setup.sh
bash ./scripts/build.sh
bash ./scripts/validate.sh
```

Optional packaging overrides:

- `LIMITLESS_STOCK_BOOT_ARCHIVE`: alternate source archive containing the stock boot member.
- `LIMITLESS_STOCK_BOOT_MEMBER`: archive member name (defaults to `stock-boot.img`).
- `LIMITLESS_MAGISKBOOT`: alternate host `magiskboot` binary.

## Baseline gates

- The generated kernel release must equal `4.14.199-27193134-abA035FXXS9CYG1`, matching the stock vendor-module vermagic.
- The stock defconfig baseline keeps `CONFIG_NET_ACT_BPF` and `CONFIG_BPF_STREAM_PARSER` disabled.
- `Module.symvers` must retain the stock `module_layout` CRC. The complete vendor-module symbol comparison is a separate validation step.
- The repacked boot must preserve the extracted stock ramdisk CPIO and embedded DTB byte-for-byte. AVB signature verification is not performed by this builder.
- No build is a confirmed boot until it has been tested on the exact SM-A035F firmware and logs have been reviewed. Do not label an untested build stable.
