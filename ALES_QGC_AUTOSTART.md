# ALES QGC Autostart Build Notes

This device tree now includes a lightweight ALES QGC test app and a small system
helper app that launches it automatically after Android finishes booting.

## What Changed

- Replaced the crashing prebuilt QGC APK with a simple platform-signed
  privileged app module named `ALES_QGC`.
- The replacement app keeps the same package/activity that the old QGC APK used:
  `org.Agosdyne.alesqgc/org.mavlink.qgroundcontrol.QGCActivity`.
- Added `apps/ALESQGCAutostart`, a platform-signed privileged Android app.
- `ALESQGCAutostart` receives `LOCKED_BOOT_COMPLETED` and `BOOT_COMPLETED`,
  waits five seconds, then starts:
  `org.Agosdyne.alesqgc/org.mavlink.qgroundcontrol.QGCActivity`.
- Added both modules to `PRODUCT_PACKAGES` in `device.mk` so they are included
  in the rpi4 system image.

## Verified Module Build

The module-only build completed successfully:

```bash
cd /home/hien/android
source build/envsetup.sh
lunch aosp_rpi4-userdebug
m ALES_QGC ALESQGCAutostart -j$(nproc)
```

Expected installed module outputs:

```text
out/target/product/rpi4/system/priv-app/ALES_QGC/ALES_QGC.apk
out/target/product/rpi4/system/priv-app/ALESQGCAutostart/ALESQGCAutostart.apk
```

## Build Flashable Image

Build the Android images:

```bash
cd /home/hien/android
source build/envsetup.sh
lunch aosp_rpi4-userdebug
make bootimage systemimage vendorimage -j$(nproc)
```

Create the Raspberry Pi 4 flashable image:

```bash
cd /home/hien/android
./rpi4-mkimg.sh
```

Expected flashable image path:

```text
out/target/product/rpi4/RaspberryVanillaAOSP13-<date>-rpi4.img
```

`rpi4-mkimg.sh` requires `sudo`, `bc`, and `kpartx`.
