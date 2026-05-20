#!/usr/bin/env bash

set -euo pipefail

TOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRODUCT_NAME="${PRODUCT_NAME:-rpi4}"
BUILD_VARIANT="${BUILD_VARIANT:-userdebug}"
LUNCH_TARGET="${PRODUCT_NAME}-${BUILD_VARIANT}"
JOBS="${JOBS:-$(nproc)}"
SKIP_BUILD="${SKIP_BUILD:-0}"
OUT_PRODUCT_DIR="${TOP_DIR}/out/target/product/${PRODUCT_NAME}"
FINAL_IMAGE="${OUT_PRODUCT_DIR}/${PRODUCT_NAME}.img"
HOST_BIN_DIR="${TOP_DIR}/out/host/linux-x86/bin"
SPARSE_CONVERTER="${HOST_BIN_DIR}/simg2img"
SGDISK_BIN="${SGDISK_BIN:-/usr/sbin/sgdisk}"
PARTED_BIN="${PARTED_BIN:-/usr/sbin/parted}"
MKFS_VFAT_BIN="${MKFS_VFAT_BIN:-/usr/sbin/mkfs.vfat}"
MTOOLS_MCOPY_BIN="${MTOOLS_MCOPY_BIN:-$(command -v mcopy || true)}"
MTOOLS_MMD_BIN="${MTOOLS_MMD_BIN:-$(command -v mmd || true)}"
BOOTFILES_DIR="${BOOTFILES_DIR:-${TOP_DIR}/device/raspberrypi/rpi4/bootfiles}"
BOOT_IMAGE_CANDIDATES=(
  "${OUT_PRODUCT_DIR}/boot.img"
  "${OUT_PRODUCT_DIR}/boot-5.4.img"
  "${OUT_PRODUCT_DIR}/boot-5.4-gz.img"
  "${OUT_PRODUCT_DIR}/boot-4.19-gz.img"
)

die() {
  echo "error: $*" >&2
  exit 1
}

note() {
  echo "[rpi4-mkimg] $*"
}

require_file() {
  local path="$1"
  [[ -f "${path}" ]] || die "missing required file: ${path}"
}

resolve_boot_image() {
  local candidate
  for candidate in "${BOOT_IMAGE_CANDIDATES[@]}"; do
    if [[ -f "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done
  return 1
}

ensure_host_tool() {
  local tool_name="$1"
  local tool_path="${HOST_BIN_DIR}/${tool_name}"

  if [[ -x "${tool_path}" ]]; then
    echo "${tool_path}"
    return 0
  fi

  note "Building host tool ${tool_name}"
  set +u
  m -j"${JOBS}" "${tool_name}" >/dev/null
  set -u
  [[ -x "${tool_path}" ]] || die "failed to build host tool ${tool_name}"
  echo "${tool_path}"
}

ensure_raw_image() {
  local src="$1"
  local dst="$2"
  local magic

  magic="$(od -An -N4 -tx1 "${src}" | tr -d ' \n')"
  if [[ "${magic}" == "3aff26ed" ]]; then
    "${SPARSE_CONVERTER}" "${src}" "${dst}" >/dev/null
  else
    cp -f "${src}" "${dst}"
  fi
}

write_partition() {
  local disk_image="$1"
  local partition_image="$2"
  local start_mib="$3"
  local raw_image="${TMP_WORK_DIR}/$(basename "${partition_image}").raw"

  ensure_raw_image "${partition_image}" "${raw_image}"
  dd if="${raw_image}" of="${disk_image}" bs=1M seek="${start_mib}" conv=notrunc status=none
}

build_boot_partition() {
  local boot_partition_image="$1"
  local boot_mount_src="${TMP_WORK_DIR}/bootfs"

  mkdir -p "${boot_mount_src}"
  if [[ -d "${BOOTFILES_DIR}" ]]; then
    cp -f "${BOOTFILES_DIR}/"* "${boot_mount_src}/" 2>/dev/null || true
  fi
  cp -f "${OUT_PRODUCT_DIR}/kernel-5.4" "${boot_mount_src}/kernel8.img"
  cp -f "${OUT_PRODUCT_DIR}/boot-5.4.img" "${boot_mount_src}/boot.img"
  cp -f "${OUT_PRODUCT_DIR}/ramdisk.img" "${boot_mount_src}/initramfs.img"
  if [[ -f "${BOOTFILES_DIR}/bcm2711-rpi-4-b.dtb" ]]; then
    cp -f "${BOOTFILES_DIR}/bcm2711-rpi-4-b.dtb" "${boot_mount_src}/bcm2711-rpi-4-b.dtb"
  else
    cp -f "${OUT_PRODUCT_DIR}/dtb.img" "${boot_mount_src}/dtb.img"
  fi

  if [[ ! -f "${boot_mount_src}/config.txt" ]]; then
    cat > "${boot_mount_src}/config.txt" <<'EOF'
arm_64bit=1
enable_uart=1
kernel=kernel8.img
initramfs initramfs.img followkernel
device_tree=bcm2711-rpi-4-b.dtb
disable_commandline_tags=1
EOF
  fi

  if [[ ! -f "${boot_mount_src}/cmdline.txt" ]]; then
    cat > "${boot_mount_src}/cmdline.txt" <<'EOF'
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootwait rw init=/init androidboot.hardware=rpi4 androidboot.selinux=permissive
EOF
  fi

  truncate -s "${BOOT_SIZE_MIB}M" "${boot_partition_image}"
  "${MKFS_VFAT_BIN}" -F 32 -n RPI-BOOT "${boot_partition_image}" >/dev/null

  if [[ -n "${MTOOLS_MCOPY_BIN}" && -n "${MTOOLS_MMD_BIN}" ]]; then
    "${MTOOLS_MCOPY_BIN}" -i "${boot_partition_image}" -s "${boot_mount_src}/"* ::/
  else
    note "mtools not found; boot FAT partition was formatted but files were not populated."
    note "Install mtools or copy boot files manually into partition 1."
  fi

  if [[ ! -f "${boot_mount_src}/start4.elf" && ! -f "${boot_mount_src}/fixup4.dat" ]]; then
    note "Pi 4 firmware files start4.elf/fixup4.dat are not present in this source tree."
    note "The image now has an MBR FAT boot partition, but it still may not boot until those firmware files are added."
  fi
}

cd "${TOP_DIR}"
require_file "${TOP_DIR}/build/envsetup.sh"
export TOP="${TOP_DIR}"
require_file "${SGDISK_BIN}"
require_file "${PARTED_BIN}"
require_file "${MKFS_VFAT_BIN}"

if [[ "${SKIP_BUILD}" != "1" ]]; then
  note "Sourcing build/envsetup.sh"
  # shellcheck source=/dev/null
  set +u
  source "${TOP_DIR}/build/envsetup.sh"

  if ! lunch "${LUNCH_TARGET}"; then
    set -u
    note "lunch ${LUNCH_TARGET} failed."
    note "Make sure the product is exported from device/raspberrypi/rpi4/AndroidProducts.mk."
    die "product ${LUNCH_TARGET} is not registered in this source tree."
  fi
  set -u
fi

mkdir -p "${OUT_PRODUCT_DIR}"
TMP_WORK_DIR="$(mktemp -d "${OUT_PRODUCT_DIR}/mkimg.XXXXXX")"
trap 'rm -rf "${TMP_WORK_DIR}"' EXIT

if [[ -x "${HOST_BIN_DIR}/simg2img" ]]; then
  SPARSE_CONVERTER="${HOST_BIN_DIR}/simg2img"
elif [[ "${SKIP_BUILD}" != "1" ]]; then
  SPARSE_CONVERTER="$(ensure_host_tool simg2img)"
else
  die "missing host tool: ${HOST_BIN_DIR}/simg2img"
fi

note "Building partition images"
if [[ "${SKIP_BUILD}" == "1" ]]; then
  note "Skipping Android rebuild and reusing existing artifacts in ${OUT_PRODUCT_DIR}"
else
  set +u
  m -j"${JOBS}" bootimage systemimage vendorimage userdataimage vbmetaimage
  set -u
fi

BOOT_IMAGE="$(resolve_boot_image)" || die "no boot image was generated under ${OUT_PRODUCT_DIR}"
SYSTEM_IMAGE="${OUT_PRODUCT_DIR}/system.img"
VENDOR_IMAGE="${OUT_PRODUCT_DIR}/vendor.img"
USERDATA_IMAGE="${OUT_PRODUCT_DIR}/userdata.img"
VBMETA_IMAGE="${OUT_PRODUCT_DIR}/vbmeta.img"

require_file "${BOOT_IMAGE}"
require_file "${SYSTEM_IMAGE}"
require_file "${VENDOR_IMAGE}"
require_file "${USERDATA_IMAGE}"
require_file "${VBMETA_IMAGE}"
require_file "${OUT_PRODUCT_DIR}/kernel-5.4"
require_file "${OUT_PRODUCT_DIR}/ramdisk.img"
require_file "${BOOTFILES_DIR}/start4.elf"
require_file "${BOOTFILES_DIR}/fixup4.dat"
require_file "${BOOTFILES_DIR}/bcm2711-rpi-4-b.dtb"

BOOT_START_MIB=1
BOOT_SIZE_MIB=256
SYSTEM_START_MIB=256
SYSTEM_SIZE_MIB=2048
VENDOR_START_MIB=2304
VENDOR_SIZE_MIB=512
USERDATA_START_MIB=2816
USERDATA_SIZE_MIB=1279
BOOTIMAGE_START_MIB=4095
BOOTIMAGE_SIZE_MIB=64
DISK_SIZE_MIB=4096

note "Creating raw disk image ${FINAL_IMAGE}"
rm -f "${FINAL_IMAGE}"
truncate -s "${DISK_SIZE_MIB}M" "${FINAL_IMAGE}"
"${PARTED_BIN}" -s "${FINAL_IMAGE}" mklabel msdos
"${PARTED_BIN}" -s "${FINAL_IMAGE}" unit MiB mkpart primary fat32 "${BOOT_START_MIB}" "${SYSTEM_START_MIB}"
"${PARTED_BIN}" -s "${FINAL_IMAGE}" set 1 boot on
"${PARTED_BIN}" -s "${FINAL_IMAGE}" unit MiB mkpart primary ext4 "${SYSTEM_START_MIB}" "${VENDOR_START_MIB}"
"${PARTED_BIN}" -s "${FINAL_IMAGE}" unit MiB mkpart primary ext4 "${VENDOR_START_MIB}" "${USERDATA_START_MIB}"
"${PARTED_BIN}" -s "${FINAL_IMAGE}" unit MiB mkpart primary ext4 "${USERDATA_START_MIB}" "${BOOTIMAGE_START_MIB}"

BOOT_FAT_IMAGE="${TMP_WORK_DIR}/boot.fat"
build_boot_partition "${BOOT_FAT_IMAGE}"

note "Writing FAT boot partition"
write_partition "${FINAL_IMAGE}" "${BOOT_FAT_IMAGE}" "${BOOT_START_MIB}"
note "Writing system partition"
write_partition "${FINAL_IMAGE}" "${SYSTEM_IMAGE}" "${SYSTEM_START_MIB}"
note "Writing vendor partition"
write_partition "${FINAL_IMAGE}" "${VENDOR_IMAGE}" "${VENDOR_START_MIB}"
note "Writing userdata partition"
write_partition "${FINAL_IMAGE}" "${USERDATA_IMAGE}" "${USERDATA_START_MIB}"

note "Image created: ${FINAL_IMAGE}"
