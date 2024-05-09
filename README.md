# CalyxOS :heart: Magisk

This repo contains scripts for building an AVB signed CalyxOS 4.x (Android 13)
image with integrated Magisk for root access.

> **Disclaimer**
> This works for me, but I don't give any guarantees. Whatever you do is on
> you, and if anything breaks you take full responsibility. Especially take
> note that you will have to wipe your device's user data when switching from
> (or back to) an official CalyxOS build.

> **Warning**
> You yourself will be responsible to watch out for security updates and apply
> them in a timely manner, as you will no longer be able to receive automatic
> updates via the official channels.

## Building

### One-time preparation

1. Clone this repository somewhere.

   ```sh
   git clone $THIS_REPO CalyxOS
   cd CalyxOS
   ```

2. Make sure that you have all the build dependencies installed.

   The scripts in this repo use bubblewrap to control the build environment and
   provide a layer of isolation against the build host. Install it with:

   ```sh
   pacman -S bubblewrap # Arch, Manjaro, ...
   apt install bubblewrap # Debian, Ubuntu, ...
   ```

   Don't forget to also install all the usual build dependencies from [the
   official CalyxOS docs].

3. Inside this repo clone, download the CalyxOS sources into the "build"
   subdirectory, as described by [the official CalyxOS docs], "Downloading the
   source code":

   ```sh
   mkdir build
   cd build
   repo init -u https://gitlab.com/CalyxOS/platform_manifest -b android13
   cd ..
   ```

   You can skip the "repo sync" command here; the build script will take care
   of that later.

4. Create the "sign" and "keys" directories, which are used for signing the
   final image, and a "tmp" directory which will be used as `/tmp` during
   building.

   ```sh
   mkdir keys sign tmp
   ```

   On modern Linux distros, `/tmp` is usually a `tmpfs` mount, i.e. a ramdisk.
   The build scripts put a lot of stuff there, which can easily eat up all
   memory and make the build fail. The "tmp" directory here is mounted into the
   build environment's `/tmp` to prevent this issue.

5. Update the `build_config.sh` file with the correct values for your device.
   Refer to the instructions in that file for more details.

6. *Optional*: Customize how many build jobs run in parallel. If your machine
   doesn't have a lot of RAM, you might otherwise run out of memory during
   compilation. In the `01-build.sh`, look for the line that says `m -j8`, and
   adjust the number as needed.

### Build / Upgrade steps

Run these two scripts every time you want to build Calyx - usually once a month
after the security updates have been released.

1. Run the build script:

   ```sh
   ./01-build.sh
   ```

   This script will:

   - Update to the latest sources
   - Build the OS, target\_files zip, and OTA tools
   - Copy these files into the `sign` folder for the next step

2. Run the signing script:

   ```sh
   ./02-sign.sh
   ```

   (Don't run `02b-magisk.sh` explicitly, it's called as part of the signing
   process.)

   This script will:

   - Download and unpack the latest Magisk APK (by calling `02b-magisk.sh`)
   - Unpack the OTA tools, and hook them to perform rooting
   - Generate missing signing keys (the old keys are backed up beforehand)
   - Sign the built image as normal, rooting the boot image in the process

To free up some disk space, you can safely delete older builds other than the
current one (after verifying that it works, of course). Look for any files at
`sign/calyx_<codename>-target_files-<something>.zip`, as well as directories
`sign/out/release-<codename>-<something>/`.

## Building without Magisk

Delete or rename the `02b-magisk.sh` file, then build as described above. The
`02-sign.sh` script will notice that the magisk hooks are missing and proceed
without rooting.

## How does this work?

For the most part, these scripts are just the build instructions from [the
official CalyxOS docs], run in a bubblewrapped environment.

The interesting part is the magisk hooks, contained in `02b-magisk.sh` and
sourced from `02-sign.sh`. This script file sets up a hook in the OTA tools, so
that they will root the boot ramdisk just before it's combined with the kernel
and signed to become the final boot image.

The hook itself mostly does what the `boot_patch.sh` from the Magisk APK also
does. The main modification is that it doesn't have to tear apart the boot
image and put it back together afterwards, and it also doesn't have to patch
the kernel.

## The Magisk app says I have to reflash

Same here. If you know how to fix this, please tell me.

In the meantime, don't take the offer to reflash. It can't properly sign the
boot image, and would render your phone unable to boot, requiring you to
manually flash a signed boot image with the recovery or bootloader.

## Zygisk doesn't work

Probably related to the error message (see above), but so far it hasn't been
important enough for me to spend more time looking into it.

Again, if you know how to fix this, please tell me.

[the official CalyxOS docs]: https://calyxos.org/docs/development/build/#downloading-the-source-code
