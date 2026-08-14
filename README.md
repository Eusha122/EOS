# EOS Privet

EOS Privet is a privacy-first, USB-live Linux distribution designed for daily use, safe defaults, and a polished macOS-inspired desktop experience.

## Product direction

- **Identity:** a plug-and-use live OS that boots from USB, starts clean, and keeps privacy features front and center without pretending to be magic.
- **Foundation:** a live `amd64` hybrid ISO for UEFI PCs, with legacy BIOS support where the base toolchain supports it.
- **Desktop:** KDE Plasma, preferring Wayland for fluid animation and touchpad behaviour, with an X11 fallback for older hardware and applications.
- **Boot model:** USB-live first. The core experience should work well without installation to an internal disk.
- **Boot experience:** before the desktop loads, show a hacker-style text screen with simple numbered choices for fresh mode or unlocking saved storage.
- **Browser:** `Void` is the privacy browser brand. The first launcher uses Debian's Tor Browser Launcher path; the old E-Browser launcher remains only as a temporary compatibility layer.
- **Privacy model:** Tails-inspired live workflow with amnesic sessions, optional encrypted persistence on the USB drive itself, and explicit warnings about threat-model limits.
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

Build the ISO from a Linux environment (native Linux, a VM, or WSL 2), not from Windows directly. The supported first build environment is a Debian 13 (`trixie`) VM; follow [`docs/build-environment.md`](docs/build-environment.md).

```bash
bash build/scripts/build-iso.sh
```

The output is written to `out/`. Build scripts intentionally keep generated files out of the source tree.

## First milestones

1. Produce and test the first EOS Privet USB-live ISO in a virtual machine.
2. Complete the EOS Privet Plasma theme, dock, top bar, login screen, and boot splash.
3. Implement the text-mode boot gate, privacy browser path, and encrypted persistence flow.
4. Add welcome-screen privacy guidance, signed updates, and the future EOS desktop app.
