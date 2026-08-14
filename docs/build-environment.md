# EOS Privet build environment

Last updated: 2026-08-15

## What to use

Build EOS Privet inside a Debian 13 (trixie) virtual machine. VirtualBox runs on Windows; Debian runs inside VirtualBox and performs the Linux ISO build. Do not build the ISO directly from Windows.

Give the build VM at least:

- 4 CPU cores if the PC has them available
- 8 GB RAM if available; 4 GB is the minimum for a slower build
- 50 GB virtual disk space
- Internet access while building

## Install build tools inside Debian

After Debian is installed in the VM, open its terminal and run:

```bash
sudo apt update
sudo apt install live-build debootstrap xorriso squashfs-tools isolinux syslinux-common grub-efi-amd64-bin mtools dosfstools ca-certificates git
```

Do not build directly from a VirtualBox shared folder such as `/media/sf_EOS`. VirtualBox shared folders do not fully support the Linux filesystem features `live-build` needs, especially symlinks.

Use the shared folder only to move files between Windows and Debian. Copy the project onto Debian's own disk first:

```bash
rm -rf "$HOME/EOS-build"
cp -a /media/sf_EOS "$HOME/EOS-build"
cd "$HOME/EOS-build"
```

Then run from the local Debian copy:

```bash
sudo bash build/scripts/build-iso.sh
```

The ISO and its checksum are written to `out/` inside the Debian copy. Copy them back to the shared folder when the build succeeds:

```bash
mkdir -p /media/sf_EOS/out
cp -a out/*.iso out/*.sha256 /media/sf_EOS/out/
```

## Clean a failed build

Failed `live-build` attempts can leave root-owned files under `build/.work/`. Clean only the local Debian copy, never the shared source folder:

```bash
cd "$HOME"
sudo umount -R "$HOME/EOS-build/build/.work/live-build/chroot" 2>/dev/null || true
sudo rm -rf "$HOME/EOS-build"
cp -a /media/sf_EOS "$HOME/EOS-build"
cd "$HOME/EOS-build"
sudo bash build/scripts/build-iso.sh
```

## Verify an ISO

From the local Debian build folder:

```bash
cd out
sha256sum --check EOS-Privet-0.1.0-dev-amd64.iso.sha256
```

The command must report `OK` before using the ISO in a VM or writing it to a USB drive.

## Test safely

Use the ISO in a new VirtualBox VM first. Do not test encrypted-storage creation on a USB containing important files. That feature is not implemented in the current test build.
