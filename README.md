# Limitless Builder

Independent build and release pipeline for Limitless on Samsung Galaxy A03 (qogirl6 / UMS9230).

## Design

- Kernel source: `a03corerooted-dev-ctrl/limitless_android_kernel_samsung_a03`.
- Builder code is independent; it does not use or modify NonGKI_Kernel_Build-K419.
- GitHub Releases and Actions are the build/publish interface.
- The pipeline produces the raw ARM64 kernel image and a repacked `boot.img`.
- The boot package currently uses `Publish/a03-A035FXXS7CXF3.tar.xz` from the kernel source and its bundled `magiskboot`. The archive supplies `stock-boot.img`; only the kernel payload is replaced, while the stock ramdisk and boot metadata are retained.
- This stock boot image is explicitly identified as firmware reference A035FXXS7CXF3. The tester's A035FXXS9CYG1 device has not yet validated this image. Treat the first package as an engineering/test artifact, not a confirmed cross-binary-compatible release.
- Do not use this A035F package for SM-A035M or SM-A035G without variant-specific boot assets and validation. DTBO packaging is not yet included.

## Entry points

- `workflow_dispatch`: manual build with a selected source ref.
- `release: published`: build the matching source tag and attach outputs to that release. Create the same tag in the kernel source repository first; otherwise use `workflow_dispatch` with an existing source ref.

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

Optional packaging overrides:

- `LIMITLESS_STOCK_BOOT_ARCHIVE`: alternate source archive containing the stock boot member.
- `LIMITLESS_STOCK_BOOT_MEMBER`: archive member name (defaults to `stock-boot.img`).
- `LIMITLESS_MAGISKBOOT`: alternate host `magiskboot` binary.

## Releases

Use tags such as `v0.1.0-alpha.1`, `v0.1.0-beta.1`, then `v1.0.0`. Each release includes the raw kernel image, repacked boot image, source commit, compiler version report, packaging provenance, build log and SHA-256 checksums. Never label an untested build stable.
