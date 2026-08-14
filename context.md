# EOS Privet context

Last updated: 2026-08-14

## Identity

**Name:** EOS Privet  
**Purpose:** a privacy-first, USB-live Linux distribution for daily use with strong security defaults and minimal setup friction.  
**Visual direction:** macOS-inspired, but with original EOS Privet branding and assets. Smoothness is a product requirement, not just decoration.

## Confirmed decisions

| Area | Decision |
| --- | --- |
| Product model | USB-live-first privacy OS with optional encrypted persistence |
| Distribution base | Current scaffold is Kali Rolling-compatible; privacy-first base choice remains open as the project pivots |
| Initial architecture | `amd64` (64-bit x86 PCs) |
| Desktop | KDE Plasma, Wayland preferred; X11 fallback retained |
| Browser direction | Tor-native privacy browser path required; current browser scaffolding is transitional |
| Privacy mode | Core product direction: Tails-inspired live mode with amnesic defaults, optional encrypted persistence, and Tor-first browsing |
| Brand asset | `assets/branding/eos-logo.svg` |
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

## Open decisions

- EOS Privet release/version numbering and licence.
- Exact KDE theme, icon set, wallpaper, sounds, and dock behaviour.
- Whether the privacy browser brand becomes `Void`.
- Whether the long-term base stays Kali-compatible or shifts to a more minimal privacy-first base.
- Persistent storage UX, unlock flow, and what data categories are allowed to persist.
- Secure-boot/signing strategy and long-term update model.
