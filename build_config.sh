#!/hint/bash
# shellcheck disable=SC2034

# Uncomment to skip the sync step and build already downloaded sources.
#readonly CALYXBUILD_NO_SYNC=1

# Set this to the codename of your device
readonly DEVICE_CODENAME=oriole

# Specify the correct target partition for your device
# Devices launched with Android 13 and up need "init_boot" here
# If you have an older device, use "boot" instead
readonly TARGET_PARTITION=boot
export TARGET_PARTITION

# Specify the correct PREINITDEVICE
# This must match the actual preinitdevice your device uses
# Pixel 6 Pro and Pixel 8 Pro use `metadata`
# To find this value, extract the following file from the latest Magisk APK
# lib/<architecture>/libmagisk*.so
# It might be called libmagisk32 or libmagisk64 depending on your device
# adb push this file to /data/local/tmp/, and rename it to `magisk`
# Full path should be `/data/local/tmp/magisk`
# Finally use adb shell to run /data/local/tmp/magisk --preinit-device
readonly PREINITDEVICE=metadata
export PREINITDEVICE
