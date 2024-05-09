#!/bin/bash -ex
cd "${0%/*}"; exec bwrap --ro-bind / / --dev-bind {,}/dev --bind {,}"$PWD" --bind "$PWD/tmp" /tmp --chdir "$PWD" -- bash -ex < <(tail -n+3 "$(readlink -f "$0")")

set -o errexit -o pipefail -o noclobber -o nounset
readonly certstring="/C=DE/O=Calyx <3 Magisk homebrew build/OU=Android RelEng/CN=Homebrewer/emailAddress=noreply@github.com"
BUILD_NUMBER=eng.$USER.$(date +%Y%m%d)
export BUILD_NUMBER

source ./build_config.sh

mkdir -p keybackups
if [[ -e keys ]]; then
  keybackup="keybackups/keys.$(date +%Y-%m-%dT%H:%M:%S).tar.zstd"
  tar cf - keys |zstd -19 > "$keybackup"
  rm -rf keys
fi
mkdir keys

( cd sign
  if [[ ! -e keys ]]; then ln -s ../keys keys; fi
  mv -v "calyx_$DEVICE_CODENAME-target_files.zip" "calyx_$DEVICE_CODENAME-target_files-${BUILD_NUMBER}.zip"
  unzip -o otatools-keys.zip
  # These commands attempt to generate some keys twice, which fails on the second attempt.
  # It's safe to ignore this error and continue anyways.
  yes "" | ./vendor/calyx/scripts/mkkeys.sh keys/"$DEVICE_CODENAME" "$certstring" || true
  yes "" | ./vendor/calyx/scripts/mkcommonkeys.sh keys/common "$certstring" || true
)

zstd -cd "$keybackup" |tar xf -

( cd sign
  unzip -o otatools.zip
)

if [[ -e ./02b-magisk.sh ]]; then
  source ./02b-magisk.sh
fi

( cd sign
  ./vendor/calyx/scripts/release.sh "$DEVICE_CODENAME" "calyx_$DEVICE_CODENAME-target_files-$BUILD_NUMBER.zip"
)
cp -v "$keybackup" "sign/out/release-$DEVICE_CODENAME-$BUILD_NUMBER/"

# shellcheck disable=SC1003
printf '\x1b]99;i=1:d=0;CalyxOS build\x1b\\'
# shellcheck disable=SC1003
printf '\x1b]99;i=1:d=1:p=body;Signing completed successfully.\x1b\\'

cat >&2 << EOF

================================================================================
[32m[1mSigning done.[m

Continue at "[1mGenerate incremental OTAs[m" or apply from recovery ([7m<Vol. Down>[m + [7m<Power>[m) with:

    adb sideload sign/out/release-$DEVICE_CODENAME-$BUILD_NUMBER/$DEVICE_CODENAME-ota_update-$BUILD_NUMBER.zip

EOF
