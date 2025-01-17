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

install -m755 "lib/arm64-v8a/libmagiskinit.so" "assets/magiskinit"
install -m755 "lib/arm64-v8a/libmagisk.so" "assets/magisk"
install -m755 "lib/x86_64/libmagiskboot.so" "assets/magiskboot"
install -m755 "lib/arm64-v8a/libinit-ld.so" "assets/init-ld"

install -m755 /dev/stdin ./root-img.sh << \_ROOT_IMG_EOF
#!/bin/bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

export PATH=$PATH:$SCRIPT_DIR
export BOOTMODE=true
export KEEPVERITY=true

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
    echo "ROOTING : Ignoring: not the target partition"
  elif [[ $KEY != */avb.pem ]]; then
    echo "ROOTING : Ignoring: not the AVB key"
  else
    echo "ROOTING : Starting to root $BOOT_IMG_PATH"
    "$MAGISK_DIR/root-img.sh" "$BOOT_IMG_PATH"
    cp -v "$MAGISK_DIR/assets/new-boot.img" "$BOOT_IMG_PATH"
  fi
fi 2>&1 |tee -a "$MAGISK_DIR/rooting.log" >&2

exec "$SCRIPT_DIR/avbtool.real" "$@"
_AVBTOOL_EOF

mv bin/toybox{,.real}
install -m755 /dev/stdin bin/toybox << \_TOYBOX_EOF
#!/bin/bash
set -o errexit -o pipefail -o noclobber -o nounset
echo "%%%%%%%%%% $(date +%Y-%m-%d\ %H:%M:%S) ${0##*/} $*" >> $MAGISK_DIR/rooting.log
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [[ $1 == cpio ]] && [[ $2 == -F ]] ;
then
        echo ignoring toybox error >> "$SCRIPT_DIR/toybox-invokes.txt"
        "$SCRIPT_DIR/toybox.real" "$@" >> "$SCRIPT_DIR/toybox-invokes.txt" 2>&1 || true
        exit 0
fi

exec "$SCRIPT_DIR/toybox.real" "$@"
_TOYBOX_EOF
)
