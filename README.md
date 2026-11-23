# Limitless Builder

Independent build and release pipeline for Limitless on Samsung Galaxy A03 (qogirl6 / UMS9230).

## Design

- Kernel source: `a03corerooted-dev-ctrl/limitless_android_kernel_samsung_a03`.
- Builder code is independent; it does not use or modify NonGKI_Kernel_Build-K419.
- GitHub Releases are the distribution interface. Actions is the build/publish backend.
- Current pipeline publishes the validated raw ARM64 kernel image. Boot/DTBO packaging remains gated until matching firmware and per-variant packaging are verified. Do not reuse A035F firmware blindly on other variants.

## Entry points

- `workflow_dispatch`: manual build with a selected source ref.
- `release: published`: build the release tag and attach outputs to that release.

## Toolchains

Configure repository Actions variables `LIMITLESS_GCC_URL` and `LIMITLESS_CLANG_URL` with trusted, immutable archive URLs for the AArch64 GCC 4.9 and Clang r383902 toolchains. Optionally set `LIMITLESS_GCC_DIR` / `LIMITLESS_CLANG_DIR` if the runner image already provides them. The pipeline does not silently substitute compiler versions.

## Local build

```sh
export LIMITLESS_SOURCE_REF=limitless/dev
export LIMITLESS_GCC_DIR=/opt/toolchains/aarch64-linux-android-4.9
export LIMITLESS_CLANG_DIR=/opt/toolchains/clang-r383902
./scripts/build.sh
./scripts/validate.sh
```

## Releases

Use tags such as `v0.1.0-alpha.1`, `v0.1.0-beta.1`, then `v1.0.0`. Every release should carry source commit, compiler/configuration metadata, logs and SHA-256 checksums. Never label an untested build stable.
