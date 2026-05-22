# Android 11 Pi 4

Scripts and device fragments used to build an Android 11 Raspberry Pi 4 image from a local AOSP 11 tree.

## What is in this repo

- `rpi4-mkimg.sh`
- `AOSP13_RPI4_BUILD_AND_INSTALL_NOTES.md`
- `device/raspberrypi/rpi4/AndroidProducts.mk`
- `device/raspberrypi/rpi4/BoardConfig.mk`
- `device/raspberrypi/rpi4/device.mk`
- `device/raspberrypi/rpi4/rpi4.mk`
- `device/raspberrypi/rpi4/bootfiles/start4.elf`
- `device/raspberrypi/rpi4/bootfiles/fixup4.dat`
- `device/raspberrypi/rpi4/bootfiles/bcm2711-rpi-4-b.dtb`

The Android 11 notes below describe this repo's scripts and fragments. See
`AOSP13_RPI4_BUILD_AND_INSTALL_NOTES.md` for the separate successful
Raspberry Vanilla AOSP 13 build and SD image flow.

## Source tree used

This work was done on a local Android 11 AOSP tree at `/home/hien/android`.

Local build version used there:

- Android release: `11`
- SDK: `30`
- Build ID: `RD2A.211001.002`

## Requirements

Host packages that were required on Ubuntu:

```bash
sudo apt update
sudo apt install mtools dosfstools gdisk parted
```

The script also expects these files to already exist in the AOSP output directory after a successful build:

- `out/target/product/rpi4/boot-5.4.img`
- `out/target/product/rpi4/kernel-5.4`
- `out/target/product/rpi4/ramdisk.img`
- `out/target/product/rpi4/system.img`
- `out/target/product/rpi4/vendor.img`
- `out/target/product/rpi4/userdata.img`
- `out/target/product/rpi4/vbmeta.img`
- `out/host/linux-x86/bin/simg2img`

## Files to place into the AOSP tree

Copy the repo files into your Android tree with this layout:

```text
<AOSP_TOP>/rpi4-mkimg.sh
<AOSP_TOP>/device/raspberrypi/rpi4/AndroidProducts.mk
<AOSP_TOP>/device/raspberrypi/rpi4/BoardConfig.mk
<AOSP_TOP>/device/raspberrypi/rpi4/device.mk
<AOSP_TOP>/device/raspberrypi/rpi4/rpi4.mk
<AOSP_TOP>/device/raspberrypi/rpi4/bootfiles/start4.elf
<AOSP_TOP>/device/raspberrypi/rpi4/bootfiles/fixup4.dat
<AOSP_TOP>/device/raspberrypi/rpi4/bootfiles/bcm2711-rpi-4-b.dtb
```

## Build flow

From the AOSP top directory:

```bash
chmod +x ./rpi4-mkimg.sh
./rpi4-mkimg.sh
```

If the Android images are already built and you only want to repack the SD image:

```bash
SKIP_BUILD=1 ./rpi4-mkimg.sh
```

Output image:

```text
out/target/product/rpi4/rpi4.img
```

## What the script does

`rpi4-mkimg.sh` currently:

- uses product name `rpi4`
- builds `bootimage`, `systemimage`, `vendorimage`, `userdataimage`, `vbmetaimage`
- creates an `msdos` partition table instead of GPT
- creates partition 1 as `FAT32` and sets the boot flag
- copies Pi firmware files into partition 1 with `mtools`
- copies these boot files into partition 1:
  - `start4.elf`
  - `fixup4.dat`
  - `bcm2711-rpi-4-b.dtb`
  - `kernel8.img` from `out/target/product/rpi4/kernel-5.4`
  - `initramfs.img` from `out/target/product/rpi4/ramdisk.img`
  - generated `config.txt`
  - generated `cmdline.txt`
- writes `system.img`, `vendor.img`, and `userdata.img` into later partitions

## Flashing the image

Check the target device first:

```bash
lsblk
```

Then write the image:

```bash
sudo dd if=out/target/product/rpi4/rpi4.img of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

Replace `/dev/sdX` with the real SD card device.

## Current technical status

This repo preserves the exact scripts and boot files used during local experimentation. It is not a full Raspberry Pi 4 Android bring-up tree.

What is confirmed:

- `rpi4.img` is generated successfully
- the image now uses `MBR/msdos`
- partition 1 is `W95 FAT32 (LBA)` and bootable
- partition 1 contains Raspberry Pi firmware files

What is not yet confirmed:

- full Android boot to userspace on real Raspberry Pi 4 hardware
- correctness of the kernel used as `kernel8.img`
- correctness of the generic Android 11 kernel/device support for `bcm2711`

Observed issue on hardware:

- the board reaches the Raspberry Pi rainbow screen and stops there

That strongly suggests the firmware partition is now readable, but the kernel/device support is still incomplete for Raspberry Pi 4.

## Important caveat

The kernel currently used for `kernel8.img` comes from the local Android 11 build output:

```text
out/target/product/rpi4/kernel-5.4
```

This is not proven to be a real Raspberry Pi 4 kernel build with correct `bcm2711` support. The current repo is therefore best treated as:

- a record of the working image-generation scripts
- a base for further Pi 4 kernel bring-up

not as a finished Raspberry Pi 4 Android distribution.

## Suggested next step

To move from image generation to real hardware boot, replace `kernel8.img` with a Raspberry Pi 4 kernel known to boot on `bcm2711`, then rebuild the image with:

```bash
SKIP_BUILD=1 ./rpi4-mkimg.sh
```
