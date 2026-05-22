# Raspberry Pi 4 AOSP 13 Build and Install Notes

This document summarizes a successful local build of Raspberry Vanilla AOSP 13
for Raspberry Pi 4 from an AOSP checkout.

## Build Target

The successful build used:

```bash
source build/envsetup.sh
lunch aosp_rpi4-userdebug
m -j$(nproc)
```

The target summary reported by the build was:

- Product: `aosp_rpi4`
- Variant: `userdebug`
- Platform: Android 13, `TQ3A.230901.001`
- Primary architecture: `arm64`
- Secondary architecture: `arm`

## Host Packages Used

The build reached the Raspberry Pi 4 libcamera Meson step and required these
host packages on Ubuntu 22.04:

```bash
sudo apt update
sudo apt install -y meson ninja-build pkg-config python3-jinja2 python3-ply
```

The generated SD card image script also requires:

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

`python3-yaml` was already installed in the successful build environment. If
the Python check reports that `yaml` is missing, install it with:

```bash
sudo apt install -y python3-yaml
```

## Incremental Rebuild Notes

Do not delete `out/` after a missing host dependency stops the build. Re-run
the same build command after installing the dependency:

```bash
m -j$(nproc)
```

Ninja will reuse completed outputs and rebuild the remaining or invalid
targets. The displayed progress percentage can be recalculated between runs and
does not mean the whole tree was rebuilt from scratch.

## Issues Seen During Build

### Missing Meson and Ninja

The first libcamera failure was:

```text
/bin/bash: line 1: meson: command not found
```

The libcamera Android make rules invoke both `meson` and host `ninja`, so install
both `meson` and `ninja-build`.

### Missing pkg-config

After Meson was installed, libcamera reported:

```text
Run-time dependency yaml-0.1 found: NO
ERROR: Git command failed: ['/usr/bin/git', 'clone',
'https://github.com/yaml/libyaml', 'libyaml']
```

The build already generates a local `yaml-0.1.pc` for libcamera. Meson could not
use it because `/usr/bin/pkg-config` was missing. Installing `pkg-config` lets
Meson discover the generated package metadata instead of trying the online
libyaml fallback.

### Missing Python Modules

The next Meson configuration error was:

```text
ERROR: python3 is missing modules: jinja2, ply, jinja2
```

Install `python3-jinja2` and `python3-ply`. The libcamera Meson files also use
the `yaml` Python module.

## Non-blocking Messages Seen

These messages appeared during the successful build but did not stop it:

```text
no declaration found for ELF symbol with id ...
```

Those messages were emitted around bionic `libm` ABI processing while the build
continued.

Libcamera also reported optional missing components such as GStreamer,
`gnutls`, `libcrypto`, Doxygen, Graphviz `dot`, and Sphinx. The successful build
did not require them for the configured Raspberry Pi 4 image.

Near the end, SystemUI emitted Kotlin and R8 warnings. The final image build
also warned that:

```text
system.img approaching size limit
```

The successful build still ended with:

```text
#### build completed successfully ####
```

## Build Outputs

The SD card image is assembled from these target outputs:

```text
out/target/product/rpi4/boot.img
out/target/product/rpi4/system.img
out/target/product/rpi4/vendor.img
```

`system.img` alone is not the full image to write to an SD card.

## Create an SD Card Image

From the AOSP checkout root, run:

```bash
./rpi4-mkimg.sh
```

The root helper is a symlink to `device/brcm/rpi4/mkimg.sh`. The script creates
a 7 GiB SD card image, writes the boot, system, and vendor images into their
partitions, and formats the userdata partition.

The output file name includes the creation date:

```text
out/target/product/rpi4/RaspberryVanillaAOSP13-YYYYMMDD-rpi4.img
```

## Write the Image to an SD Card

Write the generated `.img` file with a disk imaging tool such as Raspberry Pi
Imager or Balena Etcher.

To write it from a Linux terminal, first identify the SD card device carefully,
then run a command shaped like:

```bash
sudo dd if=out/target/product/rpi4/RaspberryVanillaAOSP13-YYYYMMDD-rpi4.img \
  of=/dev/sdX bs=4M status=progress conv=fsync
```

Replace `/dev/sdX` with the SD card device, not one of its partitions. Choosing
the wrong output device will overwrite that disk.
