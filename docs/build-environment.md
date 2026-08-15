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
sudo apt install live-build debootstrap xorriso squashfs-tools isolinux syslinux-common grub-efi-amd64-bin mtools dosfstools ca-certificates git python3
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

The ISO, checksum, resolved package list, and build-information record are written to `out/` inside the Debian copy. Copy them back to the shared folder when the build succeeds:

```bash
mkdir -p /media/sf_EOS/out
cp -f out/EOS-Privet-0.1.0-phase2d-amd64.iso \
  out/EOS-Privet-0.1.0-phase2d-amd64.iso.sha256 \
  out/EOS-Privet-0.1.0-phase2d-amd64.packages.tsv \
  out/EOS-Privet-0.1.0-phase2d-amd64.build-info.txt \
  /media/sf_EOS/out/
```

Using the exact versioned name prevents VirtualBox from silently reusing an older test ISO.

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
sha256sum --check EOS-Privet-0.1.0-phase2d-amd64.iso.sha256
```

The command must report `OK` before using the ISO in a VM or writing it to a USB drive.

## Phase 2d VM acceptance test

1. Fully power off `EOS Privet Test`. Do not use **Save State**.
2. Open **Settings > Storage**, remove the old optical disk, and attach exactly `EOS-Privet-0.1.0-phase2d-amd64.iso`.
3. Start the VM. The EOS text gate must show build `0.1.0-phase2d`.
4. Choose `2` once. It must say saved storage is not configured and return safely to the menu.
5. Choose `1`. Plasma must open without an SDDM password screen.
6. Confirm the dark EOS default wallpaper appears, with a slim top bar and centered dock.
7. Confirm the dock has Void, Dolphin, Konsole, and EOS Welcome with no blank icons.
8. Confirm there is no KDE Welcome window, `Install Debian` shortcut, or blue Debian wallpaper.

Open Konsole inside EOS and run these runtime checks:

```bash
test "$(id -un)" = eos
grep -Fx phase2d-1 "$HOME/.config/eos-privet/desktop-schema"
grep -F 'EOS desktop setup verified successfully.' "$HOME/.local/state/eos-privet/desktop-setup.log"
grep -F 'LookAndFeelPackage=org.eos.privet.desktop' "$HOME/.config/kdeglobals"
grep -F 'file:///usr/share/wallpapers/EOSPrivet/contents/images/1672x941.png' \
  "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
```

Every command must succeed. If the desktop is wrong, show the contents of:

```bash
cat "$HOME/.local/state/eos-privet/desktop-setup.log"
```

For the Fresh-session test, create `~/Documents/eos-amnesia-test`, fully power off, boot Fresh again, and confirm that file is gone. Do not mark Fresh amnesia verified until this passes.

## Test safely

Use the ISO in a new VirtualBox VM first. Do not test encrypted-storage creation on a USB containing important files. That feature is not implemented in the current test build.
