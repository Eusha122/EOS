# EOS Privet

EOS Privet is being built as a privacy-first, USB-live Linux distribution for daily use, safer defaults, and a polished macOS-inspired desktop experience. It is not release-ready yet.

## Product direction

- **Identity:** a plug-and-use live OS that boots from USB, starts clean, and keeps privacy features front and center without pretending to be magic.
- **Foundation:** a live `amd64` hybrid ISO for UEFI PCs, with legacy BIOS support where the base toolchain supports it.
- **Desktop:** KDE Plasma 6 on Wayland. An X11 fallback is a future compatibility task and is not shipped in the current Phase 2d image.
- **Boot model:** USB-live first. The core experience should work well without installation to an internal disk.
- **Boot experience:** before the desktop loads, show a hacker-style text screen with simple numbered choices for fresh mode or unlocking saved storage.
- **Browser:** `Void` is the privacy browser brand. The first launcher uses Debian's Tor Browser Launcher path; the old E-Browser launcher remains only as a temporary compatibility layer.
- **Target privacy model:** Tails-inspired live workflow with amnesic sessions, optional encrypted persistence on the USB drive itself, and explicit warnings about threat-model limits. Encrypted persistence is planned, not implemented in the current image.
- **Future app:** `eos-desktop-app` is deliberately isolated as its own package boundary. The future website-to-desktop app will replace its placeholder package without changing the OS build design.
- **Daily use:** the system should feel simple enough to plug in and use for ordinary browsing, communication, and personal work without setup friction.

EOS Privet must not claim to guarantee anonymity or make illegal activity a product goal.

## Repository guide

The three maintained documents are part of the development contract:

- [`context.md`](context.md) — decisions, product context, and active assumptions.
- [`feather's.md`](<feather's.md>) — feature catalogue and delivery status.
- [`structure.md`](structure.md) — directory ownership and component boundaries.

Update all three whenever a change affects EOS Privet's purpose, capabilities, or layout.

## Build prerequisites

Build the ISO from Linux, not directly from Windows. The tested and supported project path is the Debian 13 (`trixie`) builder VM in [`docs/build-environment.md`](docs/build-environment.md); native Linux and WSL 2 are not yet part of the verified build matrix.

```bash
sudo bash build/scripts/build-iso.sh
```

The output is written to `out/`. Before publishing it, the build opens the completed ISO and verifies its SquashFS payload, EOS identity and wallpaper bytes, trusted-file ownership, and BIOS/UEFI live-user arguments. Build scripts intentionally keep generated files out of the source tree.

## First milestones

1. Produce and test the first EOS Privet USB-live ISO in a virtual machine.
2. Boot-verify the Phase 2d EOS Plasma theme, dock, top bar, and wallpaper; then complete login-screen and boot-splash branding.
3. Complete the existing text-mode boot gate, verify the privacy browser path, and implement encrypted persistence.
4. Add welcome-screen privacy guidance, signed updates, and the future EOS desktop app.
