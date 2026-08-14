# EOS Privet feature catalogue

Last updated: 2026-08-15

Status legend: `planned` · `scaffolded` · `in progress` · `verified`

| Feature | Status | Notes |
| --- | --- | --- |
| Bootable hybrid ISO | in progress | Debian 13 (`trixie`) ISO boots in UEFI VirtualBox and reaches KDE after Fresh; repeat build and legacy BIOS checks remain. |
| USB-live-first workflow | planned | The core product should boot and run cleanly from USB without depending on installation. |
| Text-mode boot gate | verified | Gate appears before KDE and option `1` starts the desktop in the VM; future work is visual polish and saved-storage mode. |
| UEFI + legacy boot | planned | Validate both against the chosen live-build release. |
| Lightweight Plasma desktop | in progress | Plasma now ships an EOS wallpaper, Fresh-mode guide, and cleanup for Debian installer/KDE welcome noise; the rebuilt ISO still needs visual testing. |
| Smooth macOS-like experience | planned | Use Wayland, hardware acceleration, restrained effects, a dock, and original EOS styling. |
| Daily-use plug-and-use UX | in progress | Fresh session opens a plain-language EOS guide and gives the user a direct Void launch option; rebuilt ISO test still pending. |
| Void browser | scaffolded | `void-browser` starts Debian's Tor Browser Launcher; first launch needs network and remains unverified until ISO testing. |
| Tails-style privacy mode | planned | Live session should start clean, leave minimal local trace, and expose privacy limits clearly. |
| Encrypted persistent storage | planned | Optional persistence should use standard Linux disk encryption on the same USB drive and require explicit unlock. |
| Tor-first browsing path | planned | High-privacy browsing should use a Tor-native browser flow rather than relying on Chromium branding alone. |
| Default tool selection | in progress | First image keeps the privacy desktop small; authorised security tools are reserved for an optional later profile. |
| Future EOS desktop app | scaffolded | Isolated package boundary and placeholder launcher exist. |
| Internal-disk installer | planned | Secondary feature after the USB-live product is solid. |
| Signed update channel | planned | Requires project keys, hosting, and release policy. |
| Automated ISO testing | planned | Add virtual-machine boot tests after the first successful build. |
| Phased implementation roadmap | verified | `docs/implementation-plan.md` tracks delivery phases with test-based completion checkboxes. |

## Performance acceptance goals

- Responsive desktop on integrated graphics that supports the selected Plasma session.
- Animations never block input; offer a reduced-effects preset.
- No always-running heavyweight service without a user-visible purpose.
- Privacy mode must default to ephemeral state unless the user explicitly unlocks persistence.
- Everyday tasks like Wi-Fi, browsing, files, and shutdown must work without specialist knowledge.
- Files saved by the user should remain on the encrypted USB storage and show up again when the same USB is used on another PC.
- Unlocking should happen before the graphical session so users clearly choose between a fresh or saved environment.

## Safety boundary

EOS Privet must not market itself as a guarantee of anonymity, and must not present dark-web access as inherently safe.
