# EOS Privet context

Last updated: 2026-08-15

## Identity

**Name:** EOS Privet  
**Purpose:** a privacy-first, USB-live Linux distribution for daily use with strong security defaults and minimal setup friction.  
**Visual direction:** macOS-inspired, but with original EOS Privet branding and assets. Smoothness is a product requirement, not just decoration.

## Confirmed decisions

| Area | Decision |
| --- | --- |
| Product model | USB-live-first privacy OS with optional encrypted persistence on the same USB drive |
| Distribution base | Source is converted to Debian 13 for privacy and daily-use stability; repeat-build and wider hardware verification remain. |
| Pinned first build base | Debian 13 (`trixie`), so builds use a named release rather than a moving `stable` label |
| Initial architecture | `amd64` (64-bit x86 PCs) |
| Desktop | KDE Plasma 6 on Wayland for Phase 2d. An X11 fallback is not currently shipped and must not be claimed until it is explicitly packaged and tested. |
| Build workspace rule | Use VirtualBox shared folders only for transfer; run `live-build` from a native Debian filesystem such as `$HOME/EOS-build` |
| First generated artifact | `out/EOS-Privet-0.1.0-dev-amd64.iso` was produced in the Debian builder VM and reached a UEFI VM desktop; it is obsolete. |
| Old artifact warning | The Windows checksum beside the old `dev` artifact is zero bytes, so that artifact must not be reused or treated as verified. |
| Current test artifact | Next build is `out/EOS-Privet-0.1.0-phase2d-amd64.iso`. The unique name prevents VirtualBox from reusing the visually broken Phase 2b/2c images. |
| Phase 2b build finding | The first Phase 2b build stopped before producing an ISO because automatic firmware discovery selected `firmware-b43legacy-installer`. Automatic firmware discovery and package recommendations are now disabled; EOS explicitly selects common PC firmware and required desktop/network packages. Post-build verification rejects both Broadcom download-at-install firmware packages. |
| First boot-test finding | EOS gate appears before KDE and Fresh reaches the desktop; the first Phase 2 UI test still showed Debian wallpaper, KDE Welcome, and Install Debian. Double-checking found that Debian 13's `live-build` skipped the EOS hooks unless both compatibility and live hook directories were populated; that layout is now corrected, stock welcome/installer packages are removed, and the build fails if these customizations are absent. |
| Phase 2c visual finding | Phase 2c reached Plasma but still used Debian's Global Theme, wallpaper, panel layout, and launcher defaults. Phase 2d replaces the delayed best-effort wallpaper script with a valid EOS Plasma 6 Global Theme, valid wallpaper package, deterministic two-panel layout, system/new-user KDE defaults, verified launchers, and a bounded visible-error repair path. The Phase 2d VM boot test is still required. |
| Desktop build policy | The ISO build must fail if EOS theme metadata is invalid, the wallpaper bytes differ, a pinned launcher is unavailable, required Plasma runtime packages are missing, desktop entries are invalid, or KPackage cannot discover the EOS theme. |
| Boot UX | Pre-desktop text menu: `1` for fresh session, `2` for unlock saved storage |
| Fresh-session login | Phase 2b exposed that disabling all APT recommendations also omitted `live-config` and `user-setup`, so the temporary `eos` account never existed. Phase 2c explicitly includes the Debian live runtime, user creation, SDDM integration, and a boot-gate safety check. Selecting `1` must continue directly to the temporary `eos` Plasma Wayland desktop without a password prompt. |
| Browser direction | `Void` is the privacy browser brand; Tor-native browsing path required |
| Current Void implementation | Debian `torbrowser-launcher` behind an EOS `void-browser` launcher; upstream Tor Browser remains responsible for its privacy-sensitive browser code |
| Privacy mode | Core product direction: Tails-inspired live mode with amnesic defaults, optional encrypted persistence, and Tor-first browsing |
| Security promise | Reduce risk with tested, proven components; never claim EOS Privet is unhackable or fully anonymous |
| Brand asset | `assets/branding/eos-logo.svg` |
| Default wallpaper | `assets/wallpapers/cicada-default.png`, the user-supplied Cicada IV design; three other Cicada designs are selectable in Fresh mode |
| Daily-use posture | Plug-and-use daily workflow matters as much as hardening |
| Future built-in app | Website will later be packaged as the default `eos-desktop-app` |

## Non-goals for the first release

- Writing a new kernel or hardware-driver stack.
- Claiming compatibility with every PC, CPU architecture, or proprietary device.
- Developing a browser engine from scratch.
- Guaranteeing anonymity or promising "safe" access to illegal content.
- Turning the default experience into a noisy, specialist-only security lab.
- Shipping the future website application before it exists.

## Design rules

1. Keep product packages separate from the ISO build configuration.
2. Prefer configuration and packages over untracked manual desktop changes.
3. Daily-use tasks must stay easy even when privacy defaults are strict.
4. Treat smooth input, fast startup, and readable defaults as release criteria.
5. A future web app must integrate through `apps/eos-desktop-app/`, not through ad-hoc changes to the image.
6. Privacy features must state their limits clearly; EOS Privet should reduce mistakes, not promise invisibility.
7. Tor-style anonymous browsing must use a browser path designed for that threat model, not a re-skinned general browser alone.
8. Installation to internal disks is secondary to the USB-live experience.
9. User-saved files must persist on the encrypted USB storage and remain available when booting the same USB on another PC.
10. The desktop must not appear until the user chooses fresh mode or unlocks storage from the text boot gate.
11. Keep the first ISO small: authorised security-testing tools will be an optional later profile, not default background attack surface.
12. Firmware support must come from an explicit reviewed package list; never allow download-at-install firmware packages to enter builds through broad automatic discovery.
13. Desktop identity must be present before first login. Session-time repair may recover a bad configuration, but it must never be the primary theme-install mechanism or hide errors.

## Open decisions

- EOS Privet release/version numbering and licence.
- Final KDE theme polish, icon set expansion, sounds, animation tuning, and dock behaviour after the Phase 2d baseline is boot-verified.
- How `Void` is packaged in the first release: bundled Tor Browser path first, or a more customized wrapper.
- Persistent storage UX, unlock flow, and what data categories are allowed to persist.
- Whether the unlock prompt uses passphrase only, or allows a PIN-style shortcut later.
- Secure-boot/signing strategy and long-term update model.
- Release versioning, licence, and supported-PC policy.

## Delivery tracking

The detailed roadmap and its verified completion checkboxes live in [`docs/implementation-plan.md`](docs/implementation-plan.md). A phase is marked done only after its stated test conditions pass.
