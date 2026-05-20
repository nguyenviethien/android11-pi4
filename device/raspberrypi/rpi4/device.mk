$(call inherit-product, device/raspberrypi/rpi4b-led/rpi4b-led.mk)

DEVICE_MANIFEST_FILE += \
    device/raspberrypi/rpi4b-led/manifest.xml

PRODUCT_CHARACTERISTICS := tablet
PRODUCT_MODEL := Raspberry Pi 4
PRODUCT_MANUFACTURER := Raspberry Pi
