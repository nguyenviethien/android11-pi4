# Image Build and Flash Guide: `generic_arm64` vs Raspberry Pi 4B

## Why this document exists

This guide summarizes the build and flash questions from the thread and turns
them into one practical reference. The main source of confusion was that the
build output being inspected came from `generic_arm64`, while the target board
being discussed was a Raspberry Pi 4B.

Those are not the same thing.

- `generic_arm64` is a generic AOSP ARM64 product.
- Raspberry Pi 4B needs a board-specific device tree, kernel, DTB, boot
  configuration, and product target.

If we build `generic_arm64`, we get generic ARM64 images. Those images may be
useful for experimentation, but they are not the same as a correct Pi 4B image.

## What `generic_arm64` actually is

The `generic_arm64` product comes from the `device/generic/arm64` project and
is meant to provide a generic ARM64 AOSP target. It is not a Raspberry Pi 4B
product definition.

Typical build flow:

```bash
source build/envsetup.sh
lunch generic_arm64-userdebug
m -j$(nproc)
```

Build output goes to:

```bash
out/target/product/generic_arm64/
```

## What the thread confirmed about the current workspace

At the time of this discussion:

- the workspace was an AOSP `repo` checkout, not a single git repository
- `generic_arm64` build artifacts existed under
  `out/target/product/generic_arm64/`
- there was no full Raspberry Pi 4B product in the checked-in `device/`
  projects
- a separate LED integration fragment for Raspberry Pi 4B was drafted, but it
  was not connected to a full Pi 4B product target

That means:

- we can document and reason about `generic_arm64` images accurately
- we cannot claim that the current workspace already builds a real Pi 4B image

## Files that showed up in the build output

The thread surfaced these representative image files:

- `super.img`
- `system.img`
- `vendor.img`
- `vendor_boot.img`
- `userdata.img`
- `cache.img`
- `system-qemu.img`
- `vendor-qemu.img`

In another listing, `generic_arm64` also included variants such as:

- `boot-4.19-gz.img`
- `boot-5.4.img`
- `boot-5.4-gz.img`
- `boot-5.4-lz4.img`
- `vbmeta.img`

## What each image is for

### Core images

- `boot.img` or `boot-*.img`
  - kernel + ramdisk boot image
  - required for normal device boot

- `vendor_boot.img`
  - vendor-side boot components used by newer Android boot flows
  - only flash this if the target device layout has a `vendor_boot` partition

- `vbmeta.img`
  - Android Verified Boot metadata
  - usually flashed before boot/system-related partitions

- `system.img`
  - the `system` partition image

- `vendor.img`
  - the `vendor` partition image

- `super.img`
  - dynamic partition container that usually includes `system`, `vendor`, and
    possibly other logical partitions
  - when `super.img` is valid for the target, it usually replaces flashing
    `system.img` and `vendor.img` separately

- `userdata.img`
  - data partition
  - flash this only when you want a clean wipe or need to initialize user data

### Usually optional or not used for real hardware flashing

- `cache.img`
  - often irrelevant on modern builds

- `system-qemu.img`
  - for emulator/QEMU use
  - not for flashing real hardware

- `vendor-qemu.img`
  - for emulator/QEMU use
  - not for flashing real hardware

## Which files to flash from `generic_arm64`

### If the target layout uses dynamic partitions

Prefer:

- `vbmeta.img`
- `boot.img` or the appropriate `boot-*.img`
- `vendor_boot.img` if the device has a `vendor_boot` partition
- `super.img`
- `userdata.img` only if you want a wipe

When `super.img` is used, do not also flash `system.img` and `vendor.img`
unless the board-specific flashing flow explicitly says to do that.

### If the target layout does not use `super`

Use:

- `vbmeta.img`
- `boot.img` or the appropriate `boot-*.img`
- `vendor_boot.img` if required by the device
- `system.img`
- `vendor.img`
- `userdata.img` only if you want a wipe

## Recommended flashing order

When flashing partition images individually, a safe order is:

1. `vbmeta.img`
2. `boot.img` or the correct `boot-*.img`
3. `vendor_boot.img` if the partition exists
4. `super.img` or `system.img`
5. `vendor.img` if `super.img` is not being used
6. `userdata.img` if a clean reset is desired

Reasoning:

- `vbmeta.img` should match the boot and partition state
- boot-related partitions should be in place before the OS partitions are used
- `super.img` replaces separate dynamic partition flashing in the usual case
- `userdata.img` is best left until the end because it is destructive and not
  needed for every update

## Images that should not be flashed for real hardware in this case

Do not use these for a physical board flash unless you have a very specific
QEMU/emulation flow:

- `system-qemu.img`
- `vendor-qemu.img`

In most cases you should also ignore:

- `cache.img`
- `module-info.json.rsp`
- `installed-files*.txt`
- `installed-files*.json`

## Which boot image variant to pick

The thread showed several boot image variants:

- `boot-4.19-gz.img`
- `boot-5.4.img`
- `boot-5.4-gz.img`
- `boot-5.4-lz4.img`

There is no universal answer without the board's expected kernel and compression
format. The practical rule is:

- use the boot image that matches the kernel version and compression format
  expected by the target boot flow
- if you are only examining a generic build and do not have a board-specific
  requirement, `boot-5.4.img` is the least assumption-heavy choice among those
  options
- do not use `boot-debug-*` images for normal flashing

## Why this is still not a real Raspberry Pi 4B image

Even if `generic_arm64` produces bootable-looking images, that does not make the
result a Pi 4B image.

To build a proper Raspberry Pi 4B image, the workspace needs a dedicated Pi 4B
product, including at least:

- `device/<vendor>/<rpi4b>/AndroidProducts.mk`
- `device/<vendor>/<rpi4b>/device.mk`
- `device/<vendor>/<rpi4b>/BoardConfig.mk`
- Pi 4B kernel and DTB support for `bcm2711`
- Pi-specific boot files and boot flow integration
- matching init, sepolicy, manifest, and partition expectations

Then the build flow becomes board-specific, for example:

```bash
source build/envsetup.sh
lunch <rpi4b_target>-userdebug
m -j$(nproc)
```

And the output would be expected under:

```bash
out/target/product/<rpi4b_target>/
```

## Practical conclusions from the thread

### If we are dealing with `out/target/product/generic_arm64/`

Use these rules:

- flash `super.img` instead of separate `system.img` and `vendor.img` when the
  target layout supports dynamic partitions
- flash `vendor_boot.img` only if the board has a `vendor_boot` partition
- flash `vbmeta.img` before boot and OS images
- ignore `system-qemu.img` and `vendor-qemu.img` for physical hardware

### If the actual goal is Raspberry Pi 4B

Use these rules:

- do not treat `generic_arm64` output as a finished Pi 4B release
- first obtain or add a real Pi 4B product target
- only then decide the final image set and flash procedure

## Short answer cheat sheet

### For the `generic_arm64` folder shown in the thread

Flash:

- `vbmeta.img`
- `boot.img` or the correct `boot-*.img`
- `vendor_boot.img` if required by the target partition table
- `super.img`
- `userdata.img` only if you want a clean wipe

Do not flash:

- `system-qemu.img`
- `vendor-qemu.img`
- `cache.img`

### If `super.img` is not part of the target flow

Flash:

- `vbmeta.img`
- `boot.img`
- `vendor_boot.img` if present and required
- `system.img`
- `vendor.img`

## Final caution

This document captures the correct interpretation of the thread, but it does
not replace the board's actual flashing documentation. The final source of
truth is always the target board's partition layout and boot flow.

For Raspberry Pi 4B specifically, that means the board-specific product and
boot setup must exist first. Without that, `generic_arm64` remains generic.
