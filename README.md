# EOS

EOS is a lightweight, polished security-focused Linux distribution. It is built for authorised security work, ordinary daily computing, and a fast, macOS-inspired desktop experience.

## Product direction

- **Foundation:** Kali Rolling-compatible live system, packaged as an `amd64` hybrid ISO for UEFI PCs, with legacy BIOS support where the base toolchain supports it.
- **Desktop:** KDE Plasma, preferring Wayland for fluid animation and touchpad behaviour, with an X11 fallback for older hardware and applications.
- **Browser:** E-Browser, an EOS-branded Chromium launcher and profile today; a separately versioned browser product as the project matures.
- **Future app:** `eos-desktop-app` is deliberately isolated as its own package boundary. The future website-to-desktop app will replace its placeholder package without changing the OS build design.
- **Security:** tools are grouped into optional profiles so the default image stays smaller and the project can have editions later.

EOS must only be used to assess systems and networks where the user has explicit permission.

## Repository guide

The three maintained documents are part of the development contract:

- [`context.md`](context.md) — decisions, product context, and active assumptions.
- [`feather's.md`](<feather's.md>) — feature catalogue and delivery status.
- [`structure.md`](structure.md) — directory ownership and component boundaries.

Update all three whenever a change affects EOS's purpose, capabilities, or layout.

## Build prerequisites

Build the ISO from a Debian/Kali-compatible Linux environment (native Linux, a VM, or WSL 2), not from Windows directly. Install `live-build`, `debootstrap`, and the usual ISO/boot tooling from the build environment's package manager.

```bash
bash build/scripts/build-iso.sh
```

The output is written to `out/`. Build scripts intentionally keep generated files out of the source tree.

## First milestones

1. Produce and test the first EOS live ISO in a virtual machine.
2. Complete the EOS Plasma theme, dock, top bar, login screen, and boot splash.
3. Package E-Browser instead of relying on its compatibility launcher.
4. Add an installer, signed packages, updates, and the future EOS desktop app.
