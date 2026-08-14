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

Copy the EOS Privet project folder into the Debian VM, then run from the project folder:

```bash
sudo bash build/scripts/build-iso.sh
```

The ISO and its checksum are written to `out/`.

## Verify an ISO

From the project folder in Debian:

```bash
sha256sum --check out/EOS-Privet-0.1.0-dev-amd64.iso.sha256
```

The command must report `OK` before using the ISO in a VM or writing it to a USB drive.

## Test safely

Use the ISO in a new VirtualBox VM first. Do not test encrypted-storage creation on a USB containing important files. That feature is not implemented in the current test build.
