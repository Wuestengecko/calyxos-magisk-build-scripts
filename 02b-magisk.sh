#!/do-not-run-this-directly/bash -e

# NOTE: You can disable Magisk and make an unrooted ROM
# by removing or renaming this file.

rm -rf magisk
mkdir magisk
MAGISK_DIR="$(readlink -f magisk)"
export MAGISK_DIR

(
cd magisk
apk="$(wget https://raw.githubusercontent.com/topjohnwu/magisk-files/master/stable.json -qO- |jq -r .magisk.link)"
wget -O magisk.apk "$apk"
unzip magisk.apk

install -m755 /dev/stdin ./root-img.sh << \_ROOT_IMG_EOF
#!/bin/bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

export PATH=$PATH:$SCRIPT_DIR

export BOOTMODE=true
export KEEPVERITY=true

cp "$SCRIPT_DIR/lib/x86/libmagiskboot.so" "$SCRIPT_DIR/assets/magiskboot"
cp "$SCRIPT_DIR/lib/arm64-v8a/libmagisk64.so" "$SCRIPT_DIR/assets/magisk64"
cp "$SCRIPT_DIR/lib/armeabi-v7a/libmagisk32.so" "$SCRIPT_DIR/assets/magisk32"
cp "$SCRIPT_DIR/lib/arm64-v8a/libmagiskinit.so" "$SCRIPT_DIR/assets/magiskinit"

. "$SCRIPT_DIR/assets/boot_patch.sh" "$@"
_ROOT_IMG_EOF

install -m755 /dev/stdin dos2unix <<< $'#!/bin/bash\ncat $*'
install -m755 /dev/stdin getprop <<< $'#!/bin/bash\necho $*'
)

(
cd sign
mv bin/avbtool{,.real}
install -m755 /dev/stdin bin/avbtool << \_AVBTOOL_EOF
#!/bin/bash
set -o errexit -o pipefail -o noclobber -o nounset
echo "%%%%%%%%%% $(date +%Y-%m-%d\ %H:%M:%S) ${0##*/} $*" >> "$MAGISK_DIR"/rooting.log

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

prev=""
for arg in "$@"; do
  case "$prev" in
    --image) BOOT_IMG_PATH="$arg" ;;
    --partition_name) PARTITION_NAME="$arg" ;;
    --key) KEY="$arg" ;;
  esac
  prev="$arg"
done

if [[ $1 == add_hash_footer ]]; then
  if [[ $PARTITION_NAME != "$TARGET_PARTITION" ]]; then
    echo "ROOTING : Ignoring: not the target partition" >> "$MAGISK_DIR"/rooting.log
  elif [[ $KEY != */avb.pem ]]; then
    echo "ROOTING : Ignoring: not the AVB key" >> "$MAGISK_DIR"/rooting.log
  else
    echo "ROOTING : Starting to root $BOOT_IMG_PATH" >> "$MAGISK_DIR"/rooting.log
    "$MAGISK_DIR/root-img.sh" "$BOOT_IMG_PATH" >> "$MAGISK_DIR"/rooting.log
    cp -v "$MAGISK_DIR/assets/new-boot.img" "$BOOT_IMG_PATH" >> "$MAGISK_DIR"/rooting.log
  fi
fi

exec "$SCRIPT_DIR/avbtool.real" "$@"
_AVBTOOL_EOF

mv bin/toybox{,.real}
install -m755 /dev/stdin bin/toybox << \_TOYBOX_EOF
#!/bin/bash
set -o errexit -o pipefail -o noclobber -o nounset
echo "%%%%%%%%%% $(date +%Y-%m-%d\ %H:%M:%S) ${0##*/} $*" >> $MAGISK_DIR/rooting.log
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

exec "$SCRIPT_DIR/toybox.real" "$@"
_TOYBOX_EOF
)
