# EOS context

Last updated: 2026-08-14

## Identity

**Name:** EOS  
**Purpose:** a lightweight, attractive Linux distribution for daily use and authorised security testing.  
**Visual direction:** macOS-inspired, but original EOS branding and assets. Smoothness is a product requirement, not just decoration.

## Confirmed decisions

| Area | Decision |
| --- | --- |
| Distribution base | Kali Rolling-compatible Linux image |
| Initial architecture | `amd64` (64-bit x86 PCs) |
| Desktop | KDE Plasma, Wayland preferred; X11 fallback retained |
| Browser | E-Browser, initially a branded Chromium launcher/profile |
| Brand asset | `assets/branding/eos-logo.svg` |
| Security posture | Authorised testing only; tools are profile-based and documented |
| Future built-in app | Website will later be packaged as the default `eos-desktop-app` |

## Non-goals for the first release

- Writing a new kernel or hardware-driver stack.
- Claiming compatibility with every PC, CPU architecture, or proprietary device.
- Developing a browser engine from scratch.
- Shipping the future website application before it exists.

## Design rules

1. Keep product packages separate from the ISO build configuration.
2. Prefer configuration and packages over untracked manual desktop changes.
3. Never make the security toolset a hidden capability; keep it explicit and opt-in by profile.
4. Treat smooth input, fast startup, and readable defaults as release criteria.
5. A future web app must integrate through `apps/eos-desktop-app/`, not through ad-hoc changes to the image.

## Open decisions

- EOS release/version numbering and licence.
- Exact KDE theme, icon set, wallpaper, sounds, and dock behaviour.
- Default security profiles for the first public ISO.
- E-Browser privacy policy, update channel, and whether it becomes a Chromium fork.
- Installer choice and secure-boot/signing strategy.
