# AOSP 13 Raspberry Pi 4 Build and Install Notes

This document summarizes a successful local build of Raspberry Vanilla AOSP 13
for Raspberry Pi 4 from an AOSP checkout.

These notes are separate from the Android 11 scripts in this repository. The
successful AOSP 13 build used the `device/brcm/rpi4` tree and its SD image
script.

## Build Target

The successful build used:

```bash
source build/envsetup.sh
lunch aosp_rpi4-userdebug
m -j$(nproc)
```

The build summary reported:

- Product: `aosp_rpi4`
- Variant: `userdebug`
- Platform version: Android 13
- Build ID: `TQ3A.230901.001`
- Primary architecture: `arm64`
- Secondary architecture: `arm`

## Host Packages Used

The libcamera Meson build required these packages on Ubuntu 22.04:

```bash
sudo apt update
sudo apt install -y meson ninja-build pkg-config python3-jinja2 python3-ply
```

The SD card image script also requires:

```bash
sudo apt install -y kpartx
```

Helpful checks before resuming the build:

```bash
meson --version
ninja --version
pkg-config --version
python3 -c "import jinja2, ply, yaml; print('OK')"
```

`python3-yaml` was already present in the successful build environment. If the
Python check reports a missing `yaml` module, install it with:

```bash
sudo apt install -y python3-yaml
```

## Incremental Rebuild Notes

Do not delete `out/` after a missing host dependency stops the build. Install
the missing dependency and run the same build command again:

```bash
m -j$(nproc)
```

Ninja reuses valid completed outputs and rebuilds the remaining or invalid
targets. The progress percentage can be recalculated between runs, so a changed
percentage does not mean the tree was rebuilt from scratch.

## Errors Seen and Fixes

### Meson and Ninja Missing

The first libcamera failure was:

```text
/bin/bash: line 1: meson: command not found
```

The libcamera Android make rules invoke both host `meson` and host `ninja`.
Install `meson` and `ninja-build`.

### pkg-config Missing

After Meson was installed, libcamera reported:

```text
Run-time dependency yaml-0.1 found: NO
ERROR: Git command failed: ['/usr/bin/git', 'clone',
'https://github.com/yaml/libyaml', 'libyaml']
```

The Android build already generated a local `yaml-0.1.pc` for libcamera. Meson
could not use that package metadata because `/usr/bin/pkg-config` was missing,
so it fell back to trying to clone libyaml. Install `pkg-config`.

### Python Modules Missing

The next Meson configuration error was:

```text
ERROR: python3 is missing modules: jinja2, ply, jinja2
```

Install `python3-jinja2` and `python3-ply`. The libcamera Meson files also use
the `yaml` Python module.

## Non-blocking Build Messages

These bionic `libm` ABI messages appeared while the build continued:

```text
no declaration found for ELF symbol with id ...
```

Libcamera also reported optional missing components such as GStreamer,
`gnutls`, `libcrypto`, Doxygen, Graphviz `dot`, and Sphinx. They were not
required for this configured Raspberry Pi 4 image.

Near the end of the successful build, SystemUI emitted Kotlin and R8 warnings.
The image build also warned:

```text
system.img approaching size limit
```

The build still ended with:

```text
#### build completed successfully ####
```

## AOSP 13 Outputs

The SD card image flow uses these outputs:

```text
out/target/product/rpi4/boot.img
out/target/product/rpi4/system.img
out/target/product/rpi4/vendor.img
```

`system.img` alone is not the complete image to write to an SD card.

## Create the AOSP 13 SD Card Image

From the AOSP checkout root, run:

```bash
./rpi4-mkimg.sh
```

In the AOSP 13 checkout used here, the root helper links to
`device/brcm/rpi4/mkimg.sh`. The script creates a 7 GiB SD card image, writes
the boot, system, and vendor images into their partitions, and formats the
userdata partition.

The generated file name includes the creation date:

```text
out/target/product/rpi4/RaspberryVanillaAOSP13-YYYYMMDD-rpi4.img
```

## Write the Image to an SD Card

Write the generated `.img` file with Raspberry Pi Imager, Balena Etcher, or a
carefully targeted Linux command such as:

```bash
sudo dd if=out/target/product/rpi4/RaspberryVanillaAOSP13-YYYYMMDD-rpi4.img \
  of=/dev/sdX bs=4M status=progress conv=fsync
```

Replace `/dev/sdX` with the SD card device, not one of its partitions. The wrong
output device will overwrite that disk.
