include build/make/target/board/generic_arm64/BoardConfig.mk
include device/raspberrypi/rpi4b-led/BoardConfig-rpi4b-led.mk

TARGET_BOOTLOADER_BOARD_NAME := rpi4
TARGET_BOARD_PLATFORM := bcm2711
TARGET_KERNEL_USE := 5.4
BOARD_KERNEL_BINARIES := kernel-5.4
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
