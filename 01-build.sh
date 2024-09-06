#!/bin/bash -x
cd "${0%/*}"; exec bwrap --ro-bind / / --dev-bind {,}/dev --bind {,}/etc --tmpfs /home --bind {,}"$PWD" --bind "$PWD/tmp" /tmp --chdir "$PWD" -- bash < <(tail -n+3 "$(readlink -f "$0")")

source ./build_config.sh

if ! python -c 'from google.protobuf import descriptor' &> /dev/null; then
  echo >&2 'Python protobuf is not installed. Please install it and try again.'
  exit 1
fi

if [[ ! -e build/.repo ]]; then
  echo >&2 'There is no repo checkout in build/.repo.'
  echo >&2 'Please run the correct "repo init" command first.'
  exit 1
fi

(
  set -ex
  cd build
  if [[ $CALYXBUILD_NO_SYNC != 1 ]]; then
    repo sync \
      --jobs-network=4 --jobs-checkout=8 \
      --current-branch --detach --force-remove-dirty --force-sync
    git lfs install
    # shellcheck disable=SC2016
    repo forall --jobs=4 -epv \
      -c sh -c 'git lfs install && git lfs pull $(git remote | head -n1) -I ""'

    ./calyx/scripts/pixel/device.sh "$DEVICE_CODENAME"
  else
    printf '\x1b[33m%s\x1b[m\n' "Skipping repo sync"
  fi

  # shellcheck source=build/build/envsetup.sh
  source build/envsetup.sh
  lunch "$RELEASE_CODE"

  ##########################################################
  # You may want to change the number of parallel jobs here.
  m -j8
  ##########################################################

  m target-files-package -j2
  m otatools-package -j2
  m otatools-keys-package -j2

  mkdir -p ../sign
  cp "$OUT"/otatools{,-keys}.zip "$OUT"/obj/PACKAGING/target_files_intermediates/*.zip ../sign/
)
r=$?

if ((r == 0)); then
  msg='Build completed successfully.'
else
  msg="Build failed! Exit code: $r"
fi

# shellcheck disable=SC1003
printf '\x1b]99;i=1:d=0;CalyxOS build\x1b\\'
# shellcheck disable=SC1003
printf '\x1b]99;i=1:d=1:p=body;%s\x1b\\' "$msg"

if ((r == 0)); then cat >&2 << EOF

================================================================================
[32m[1mBuild completed.[m

You can now sign it with:

  ./02-sign.sh

EOF
fi
